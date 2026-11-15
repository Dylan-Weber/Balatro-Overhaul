import { describe, it, expect, afterAll } from 'bun:test';
import { startServer, sanitizeSettings } from './index';
import { cleanRunMods, runModsOn, RUN_MODS_MAX_IDS } from './run_mods';
import { rankedSettings } from './rulesets_server';

type Msg = Record<string, unknown>;
const srv = startServer(0);
afterAll(() => srv.stop(true));

interface C { send: (m: Msg) => void; wait: (t: string, ms?: number) => Promise<Msg>; close: () => void; }

let uid = 0;
const nm = () => `Mods${++uid}x${Math.floor(Math.random() * 1e6)}`;

function decode(raw: string): Msg {
  const parsed = JSON.parse(raw) as Msg;
  if (parsed.z === 1 && typeof parsed.d === 'string') return JSON.parse(Buffer.from(Bun.inflateSync(Buffer.from(parsed.d, 'base64'))).toString('utf8')) as Msg;
  return parsed;
}

async function connect(): Promise<C> {
  const ws = new WebSocket(`ws://127.0.0.1:${srv.port}/ws`);
  const msgs: Msg[] = [];
  const waiters: { t: string; resolve: (m: Msg) => void }[] = [];
  ws.onmessage = (ev) => {
    const m = decode(String(ev.data));
    const i = waiters.findIndex((w) => w.t === m.type);
    if (i >= 0) { waiters[i].resolve(m); waiters.splice(i, 1); } else msgs.push(m);
  };
  await new Promise<void>((res, rej) => { ws.onopen = () => res(); ws.onerror = () => rej(new Error('ws')); });
  return {
    send: (m) => ws.send(JSON.stringify(m)),
    wait: (t, ms = 2000) => {
      const i = msgs.findIndex((m) => m.type === t);
      if (i >= 0) return Promise.resolve(msgs.splice(i, 1)[0]);
      return new Promise<Msg>((res, rej) => {
        const to = setTimeout(() => rej(new Error('timeout ' + t)), ms);
        waiters.push({ t, resolve: (m) => { clearTimeout(to); res(m); } });
      });
    },
    close: () => ws.close(),
  };
}

const MIX = { decks: ['b_red:discards', 'b_blue:hands', 'b_black:joker_slot'], off: ['stake_black:eternal'] };

describe('run modifiers setting', () => {
  it('keeps piece ids, sorted and once each', () => {
    expect(cleanRunMods({ decks: ['b_red:discards', 'b_blue:hands', 'b_red:discards'], off: ['stake_black:eternal'] }))
      .toEqual({ decks: ['b_blue:hands', 'b_red:discards'], off: ['stake_black:eternal'] });
  });

  it('drops junk ids, wrong types and long lists', () => {
    const many = Array.from({ length: 400 }, (_, i) => `b_x${i}:hands`);
    const r = cleanRunMods({ decks: [...many, 7, '', 'nocolon', 'a:b c', 'x'.repeat(70) + ':y', { a: 1 }], off: 'nope' })!;
    expect(r.decks.length).toBe(RUN_MODS_MAX_IDS);
    expect(r.decks.every((x) => /^[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+$/.test(x))).toBe(true);
    expect(r.off).toEqual([]);
    expect(cleanRunMods('bad')).toBeUndefined();
    expect(cleanRunMods([1, 2])).toBeUndefined();
    expect(cleanRunMods([])).toEqual({ decks: [], off: [] });
  });

  it('is on only when something is picked', () => {
    expect(runModsOn({ run_mods: MIX })).toBe(true);
    expect(runModsOn({ run_mods: { decks: [], off: [] } })).toBe(false);
    expect(runModsOn({})).toBe(false);
  });

  it('sanitizeSettings cleans it and removes a bad one', () => {
    expect(sanitizeSettings({ run_mods: { decks: ['b_red:discards', 5], off: ['stake_gold:rental'] } })!.run_mods).toEqual({ decks: ['b_red:discards'], off: ['stake_gold:rental'] });
    expect(sanitizeSettings({ run_mods: 'lots' })!.run_mods).toBeUndefined();
  });

  it('ranked settings never carry modifiers', () => {
    expect((rankedSettings() as Msg).run_mods).toBeUndefined();
  });

  it('the host mix reaches the guest in lobby settings and at match start', async () => {
    const host = await connect();
    const guest = await connect();
    host.send({ type: 'create_room', visibility: 'public', name: nm() });
    const created = await host.wait('room_created');
    guest.send({ type: 'join_room', code: created.code, name: nm() });
    await guest.wait('room_ready');
    host.send({ type: 'match_settings', settings: { mode: 'nemesis', run_mods: { ...MIX, decks: [...MIX.decks, 'bad id'] } } });
    const got = await guest.wait('match_settings');
    expect((got.settings as Msg).run_mods).toEqual({ decks: ['b_black:joker_slot', 'b_blue:hands', 'b_red:discards'], off: ['stake_black:eternal'] });
    host.send({ type: 'match_start', seed: 'MODS1', settings: { mode: 'nemesis', starting_lives: 1, run_mods: MIX }, player_name: 'H' });
    const ms = await guest.wait('match_start');
    expect((ms.settings as Msg).run_mods).toEqual({ decks: ['b_black:joker_slot', 'b_blue:hands', 'b_red:discards'], off: ['stake_black:eternal'] });
    host.close(); guest.close();
  });

  it('clearing the mix with an empty table reaches the guest', async () => {
    const host = await connect();
    const guest = await connect();
    host.send({ type: 'create_room', visibility: 'public', name: nm() });
    const created = await host.wait('room_created');
    guest.send({ type: 'join_room', code: created.code, name: nm() });
    await guest.wait('room_ready');
    host.send({ type: 'match_settings', settings: { run_mods: MIX } });
    await guest.wait('match_settings');
    host.send({ type: 'match_settings', settings: { run_mods: [] } });
    const got = await guest.wait('match_settings');
    expect((got.settings as Msg).run_mods).toEqual({ decks: [], off: [] });
    host.send({ type: 'match_start', seed: 'MODS2', settings: { mode: 'nemesis', starting_lives: 1 }, player_name: 'H' });
    const ms = await guest.wait('match_start');
    expect((ms.settings as Msg).run_mods).toEqual({ decks: [], off: [] });
    host.close(); guest.close();
  });

  it('a guest cannot change the mix', async () => {
    const host = await connect();
    const guest = await connect();
    host.send({ type: 'create_room', visibility: 'public', name: nm() });
    const created = await host.wait('room_created');
    guest.send({ type: 'join_room', code: created.code, name: nm() });
    await guest.wait('room_ready');
    guest.send({ type: 'match_settings', settings: { run_mods: MIX } });
    await expect(host.wait('match_settings', 300)).rejects.toThrow();
    host.close(); guest.close();
  });
});
