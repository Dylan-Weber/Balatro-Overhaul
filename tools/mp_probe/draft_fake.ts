import { writeFileSync } from 'node:fs';

type Msg = Record<string, unknown>;
const [port, roomFile, version, lifeSec, hostFilter] = process.argv.slice(2);
const VANILLA = new Set(['Red Deck', 'Blue Deck', 'Yellow Deck', 'Green Deck', 'Black Deck', 'Magic Deck', 'Nebula Deck', 'Ghost Deck',
  'Abandoned Deck', 'Checkered Deck', 'Zodiac Deck', 'Painted Deck', 'Anaglyph Deck', 'Plasma Deck', 'Erratic Deck']);
const say = (...a: unknown[]) => console.log('[draft host]', ...a);
const filter = hostFilter && hostFilter !== 'none' ? { deck_filter: hostFilter } : {};

function decode(s: string): Msg {
  const p = JSON.parse(s) as Msg;
  if (p.z === 1 && typeof p.d === 'string') return JSON.parse(Buffer.from(Bun.inflateSync(Buffer.from(p.d, 'base64'))).toString('utf8')) as Msg;
  return p;
}

const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
const send = (m: Msg) => ws.send(JSON.stringify(m));
let started = false;
ws.onmessage = (ev) => {
  const m = decode(String(ev.data));
  if (m.type !== 'pong' && m.type !== 'ping') say('got', m.type, m.reason ?? '');
  if (m.type === 'room_created') writeFileSync(roomFile, `${String(m.code)} ${String(m.id)}\n`);
  if (m.type === 'room_ready') {
    send({ type: 'match_settings', settings: { deck_draft: true, different_decks: true } });
    send({ type: 'player_name', name: 'FakeHost' });
  }
  if (m.type === 'room_joined' && !started) {
    started = true;
    say('guest deck_filter', String(m.deck_filter));
    send({ type: 'room_joined', player: { name: 'FakeHost' }, mp_version: 10, version: 'V 2.1 - Overhaul', ...filter });
    setTimeout(() => send({ type: 'draft_start', ...filter }), 2500);
  }
  if (m.type === 'draft_state' && Array.isArray(m.pool)) {
    const pool = m.pool as string[];
    const extra = pool.filter(d => !VANILLA.has(d));
    say(`POOL ${pool.join(',')}`);
    say(`CHECK non-vanilla in pool: ${extra.length > 0 ? extra.join(',') : 'none'}`);
  }
};
await new Promise<void>((r) => { ws.onopen = () => r(); });
send({ type: 'create_room', visibility: 'private', name: 'FakeHost', pkey: 'H'.repeat(20) + '4444', version, ...filter });
await Bun.sleep(Number(lifeSec || 120) * 1000);
ws.close();
process.exit(0);
