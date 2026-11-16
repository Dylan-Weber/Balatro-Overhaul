import { describe, it, expect, afterAll } from 'bun:test';
import { startServer, adminLive } from './index';

const srv = startServer(0);
afterAll(() => srv.stop(true));

type Msg = Record<string, unknown>;

async function connect(): Promise<{ ws: WebSocket; msgs: Msg[] }> {
  const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/ws`);
  const msgs: Msg[] = [];
  ws.onmessage = (ev) => { try { msgs.push(JSON.parse(String(ev.data)) as Msg); } catch { } };
  await new Promise<void>((resolve, reject) => { ws.onopen = () => resolve(); ws.onerror = () => reject(new Error('ws error')); });
  return { ws, msgs };
}

const settle = () => new Promise(r => setTimeout(r, 150));
const key = (c: string) => c.repeat(20) + String(1000 + Math.floor(Math.random() * 9000));
const live = (name: string) => adminLive().sockets.filter(s => s.name === name);

describe('client_hello', () => {
  it('names the connection and records its version right away', async () => {
    const name = `Hel${Math.floor(Math.random() * 1e5)}`;
    const c = await connect();
    c.ws.send(JSON.stringify({ type: 'client_hello', name, pkey: key('a'), version: '72' }));
    await settle();
    const s = live(name);
    expect(s.length).toBe(1);
    expect(s[0].version).toBe('72');
    c.ws.close();
  });

  it('shows a default name without refusing it', async () => {
    const c = await connect();
    c.ws.send(JSON.stringify({ type: 'client_hello', name: 'Player', pkey: key('b'), version: '72' }));
    await settle();
    expect(live('Player').length).toBeGreaterThan(0);
    expect(c.msgs.some(m => m.type === 'name_refused')).toBe(false);
    c.ws.close();
  });

  it('keeps a name held by someone else for display only', async () => {
    const name = `Twin${Math.floor(Math.random() * 1e5)}`;
    const a = await connect();
    a.ws.send(JSON.stringify({ type: 'client_hello', name, pkey: key('c'), version: '72' }));
    await settle();
    const b = await connect();
    b.ws.send(JSON.stringify({ type: 'client_hello', name, pkey: key('d'), version: '72' }));
    await settle();
    expect(live(name).length).toBe(2);
    expect(b.msgs.some(m => m.type === 'name_refused')).toBe(false);
    a.ws.close(); b.ws.close();
  });
});
