import { describe, it, expect, afterAll } from 'bun:test';
import { startServer, validateMessage } from './index';

const srv = startServer(0);
afterAll(() => srv.stop(true));

type Msg = Record<string, unknown>;
interface C { msgs: Msg[]; send: (m: Msg) => void; next: (type: string, ms?: number) => Promise<Msg>; close: () => void }

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
let uid = 0;
const nm = (p: string) => `${p}${++uid}w${Math.floor(Math.random() * 1e5)}`;
const key = (c: string) => c.repeat(20) + String(1000 + Math.floor(Math.random() * 9000));

function decode(raw: string): Msg {
  const parsed = JSON.parse(raw) as Msg;
  if (parsed.z === 1 && typeof parsed.d === 'string') return JSON.parse(Buffer.from(Bun.inflateSync(Buffer.from(parsed.d, 'base64'))).toString('utf8')) as Msg;
  return parsed;
}

async function connect(): Promise<C> {
  const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/ws`);
  const msgs: Msg[] = [];
  const seen: Record<string, number> = {};
  const waiters: { type: string; resolve: (m: Msg) => void }[] = [];
  ws.onmessage = (ev) => {
    const m = decode(String(ev.data));
    msgs.push(m);
    const i = waiters.findIndex(w => w.type === m.type);
    if (i >= 0) { seen[String(m.type)] = msgs.length; waiters.splice(i, 1)[0].resolve(m); }
  };
  await new Promise<void>((resolve, reject) => { ws.onopen = () => resolve(); ws.onerror = () => reject(new Error('ws error')); });
  return {
    msgs,
    send: (m) => ws.send(JSON.stringify(m)),
    next: (type, ms = 2000) => {
      const from = seen[type] ?? 0;
      const at = msgs.findIndex((m, i) => i >= from && m.type === type);
      if (at >= 0) { seen[type] = at + 1; return Promise.resolve(msgs[at]); }
      return new Promise<Msg>((resolve, reject) => {
        const t = setTimeout(() => reject(new Error(`timed out waiting for ${type}`)), ms);
        waiters.push({ type, resolve: (m) => { clearTimeout(t); resolve(m); } });
      });
    },
    close: () => ws.close(),
  };
}

const count = (c: C, type: string) => c.msgs.filter(m => m.type === type).length;

async function rankedPair(): Promise<[C, C]> {
  const ver = `wait-test-${++uid}`;
  const a = await connect();
  a.send({ type: 'find_match', ranked: true, name: nm('Ra'), pkey: key('a'), version: ver, mods: [] });
  await a.next('searching');
  const b = await connect();
  b.send({ type: 'find_match', ranked: true, name: nm('Rb'), pkey: key('b'), version: ver, mods: [] });
  await a.next('room_ready');
  await b.next('room_ready');
  return [a, b];
}

describe('wait_status validation', () => {
  it('accepts the known statuses and null', () => {
    for (const status of ['solo', 'wait', 'lobby', null]) expect(validateMessage({ type: 'wait_status', status }, 40)).toBeNull();
  });
  it('refuses anything else', () => {
    expect(validateMessage({ type: 'wait_status', status: 'dance' }, 40)).toContain('wait_status');
    expect(validateMessage({ type: 'wait_status', status: 3 }, 40)).toContain('wait_status');
    expect(validateMessage({ type: 'wait_status' }, 40)).toContain('wait_status');
  });
});

describe('wait_status in a ranked match that was just found', () => {
  it('relays solo, wait and lobby to the other player with the name and seat', async () => {
    const [a, b] = await rankedPair();
    a.send({ type: 'wait_status', status: 'solo' });
    const s1 = await b.next('wait_status');
    expect(s1.status).toBe('solo');
    expect(s1.pid).toBe(0);
    expect(typeof s1.name).toBe('string');
    b.send({ type: 'wait_status', status: 'wait' });
    const s2 = await a.next('wait_status');
    expect(s2.status).toBe('wait');
    expect(s2.pid).toBe(1);
    a.send({ type: 'wait_status', status: 'lobby' });
    expect((await b.next('wait_status')).status).toBe('lobby');
    await sleep(80);
    expect(count(a, 'error')).toBe(0);
    expect(count(b, 'error')).toBe(0);
    a.close(); b.close();
  });

  it('never echoes the status back to the sender', async () => {
    const [a, b] = await rankedPair();
    a.send({ type: 'wait_status', status: 'solo' });
    await b.next('wait_status');
    await sleep(80);
    expect(count(a, 'wait_status')).toBe(0);
    a.close(); b.close();
  });

  it('the waiting player gets room_closed when the other one leaves', async () => {
    const [a, b] = await rankedPair();
    a.send({ type: 'wait_status', status: 'wait' });
    await b.next('wait_status');
    b.send({ type: 'leave_lobby' });
    const closed = await a.next('room_closed');
    expect(closed.reason).toBe('opponent_left');
    a.send({ type: 'find_match', ranked: true, name: nm('Again'), pkey: key('c'), version: 'wait-again', mods: [] });
    expect((await a.next('searching')).ranked).toBe(true);
    a.close(); b.close();
  });

  it('the waiting player gets room_closed when the other one drops', async () => {
    const [a, b] = await rankedPair();
    b.send({ type: 'wait_status', status: 'solo' });
    await a.next('wait_status');
    b.close();
    expect((await a.next('room_closed')).reason).toBe('opponent_disconnected');
    a.close();
  });

  it('the match still starts as usual once both are ready', async () => {
    const [a, b] = await rankedPair();
    a.send({ type: 'wait_status', status: 'wait' });
    await b.next('wait_status');
    a.send({ type: 'wait_status', status: 'lobby' });
    await b.next('wait_status');
    b.send({ type: 'room_joined', player: { name: 'b' } });
    a.send({ type: 'room_joined', player: { name: 'a' } });
    await sleep(60);
    a.send({ type: 'match_start', seed: 'WAITPLAY' });
    expect((await b.next('match_start')).type).toBe('match_start');
    b.send({ type: 'wait_status', status: 'solo' });
    await sleep(80);
    expect(count(a, 'wait_status')).toBe(0);
    a.close(); b.close();
  });
});

describe('wait_status in a normal room', () => {
  it('a guest who joins later hears what the host is doing', async () => {
    const h = await connect();
    h.send({ type: 'create_room', visibility: 'private', name: nm('Host'), pkey: key('H') });
    const created = await h.next('room_created');
    h.send({ type: 'wait_status', status: 'solo' });
    await sleep(60);
    const g = await connect();
    g.send({ type: 'join_room', code: created.code, id: created.id, name: nm('Guest'), pkey: key('G') });
    await g.next('room_ready');
    const st = await g.next('wait_status');
    expect(st.status).toBe('solo');
    expect(st.pid).toBe(0);
    g.send({ type: 'wait_status', status: 'wait' });
    expect((await h.next('wait_status')).status).toBe('wait');
    h.close(); g.close();
  });

  it('a host back in the lobby clears it for the next guest', async () => {
    const h = await connect();
    h.send({ type: 'create_room', visibility: 'private', name: nm('Host'), pkey: key('H') });
    const created = await h.next('room_created');
    h.send({ type: 'wait_status', status: 'solo' });
    h.send({ type: 'wait_status', status: null });
    await sleep(60);
    const g = await connect();
    g.send({ type: 'join_room', code: created.code, id: created.id, name: nm('Guest'), pkey: key('G') });
    await g.next('room_ready');
    await sleep(120);
    expect(count(g, 'wait_status')).toBe(0);
    h.close(); g.close();
  });

  it('a socket with no room is ignored', async () => {
    const c = await connect();
    c.send({ type: 'wait_status', status: 'solo' });
    await sleep(80);
    expect(count(c, 'error')).toBe(0);
    expect(count(c, 'wait_status')).toBe(0);
    c.close();
  });
});

describe('wait_status in a party lobby', () => {
  async function party(n: number): Promise<{ host: C; others: C[]; code: string }> {
    const host = await connect();
    host.send({ type: 'party_create', name: nm('Ph'), kind: 'br' });
    const joined = await host.next('party_joined');
    const code = String(joined.code);
    const others: C[] = [];
    for (let i = 1; i < n; i++) {
      const c = await connect();
      c.send({ type: 'party_join', code, name: nm('Pj') });
      await c.next('party_joined');
      others.push(c);
    }
    await sleep(80);
    return { host, others, code };
  }

  it('every other player hears it, and party_room carries it per player', async () => {
    const { host, others } = await party(3);
    const [b, c] = others;
    b.send({ type: 'wait_status', status: 'solo' });
    const toHost = await host.next('wait_status');
    const toC = await c.next('wait_status');
    expect(toHost.status).toBe('solo');
    expect(toHost.party).toBe(true);
    expect(toC.pid).toBe(toHost.pid);
    await sleep(80);
    expect(b.msgs.filter(m => m.type === 'wait_status').length).toBe(0);
    const rooms = host.msgs.filter(m => m.type === 'party_room');
    const last = rooms[rooms.length - 1];
    const me = (last.players as Msg[]).find(p => p.pid === toHost.pid);
    expect(me?.wait).toBe('solo');
    const someone = (last.players as Msg[]).find(p => p.pid !== toHost.pid);
    expect(someone?.wait).toBeNull();
    host.close(); b.close(); c.close();
  });

  it('ready still works for a player who chose Wait', async () => {
    const { host, others } = await party(3);
    const [b, c] = others;
    c.send({ type: 'wait_status', status: 'wait' });
    await host.next('wait_status');
    c.send({ type: 'party_ready', ready: true });
    await sleep(100);
    const rooms = host.msgs.filter(m => m.type === 'party_room');
    const last = rooms[rooms.length - 1];
    const seat = (last.players as Msg[]).find(p => p.wait === 'wait');
    expect(seat?.ready).toBe(true);
    host.close(); b.close(); c.close();
  });
});
