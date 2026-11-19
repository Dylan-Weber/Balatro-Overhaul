import { describe, it, expect } from 'bun:test';
import { Database } from 'bun:sqlite';
import { ForgeBoard, MemoryForgeStore, D1ForgeStore, validateForge, checkMod, cleanCredits, themeInfo, forgeWeek, forgeHandlers, setForgeBoard, forgeBoard, FORGE_THEMES, FORGE_WEEK_EPOCH, FORGE_WEEK_MS, FORGE_THEME_PER_PAGE, FORGE_PUBLISH_GAP_MS, type ForgeStore } from './forge_mods';

const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAEcAAABfCAYAAAA=';
const K1 = 'A'.repeat(24);
const K2 = 'B'.repeat(24);
const K3 = 'C'.repeat(24);
const K4 = 'D'.repeat(24);
const K5 = 'E'.repeat(24);
const WEEK0 = FORGE_WEEK_EPOCH + 10 * FORGE_WEEK_MS + 3600_000;

function mod(o: Record<string, unknown> = {}): string {
  return JSON.stringify({
    format: 'forgemod', v: 16, id: 'abc123', name: 'Heart Pack', author: 'Tester', about: ['Hearts get stronger.'], version: 1, made: 1,
    jokers: [{ id: 'hthief', name: 'Heart Thief' }], creations: [], files: { hthief: PNG }, ...o,
  });
}

function sqliteD1() {
  const db = new Database(':memory:');
  return {
    kind: 'd1',
    db,
    query: async (sql: string, params: unknown[] = []) => {
      const st = db.prepare(sql);
      if (st.columnNames.length > 0) return st.all(...(params as never[])) as Record<string, unknown>[];
      st.run(...(params as never[]));
      return [];
    },
    write: () => undefined,
  };
}

function boards(): { name: string; make: () => { b: ForgeBoard; clock: { t: number }; store: ForgeStore } }[] {
  return [
    { name: 'memory', make: () => { const clock = { t: WEEK0 }; const store = new MemoryForgeStore(); return { b: new ForgeBoard(store, { now: () => clock.t }), clock, store }; } },
    { name: 'sqlite d1', make: () => { const clock = { t: WEEK0 }; const store = new D1ForgeStore(sqliteD1()); return { b: new ForgeBoard(store, { now: () => clock.t }), clock, store }; } },
  ];
}

describe('validateForge for ratings, plays and themes', () => {
  it('checks forge_rate', () => {
    expect(validateForge({ type: 'forge_rate', id: 'abc123', stars: 5 })).toBeNull();
    expect(validateForge({ type: 'forge_rate', id: 'abc123', stars: 0 })).toBe('forge_rate: invalid stars');
    expect(validateForge({ type: 'forge_rate', id: 'abc123', stars: 6 })).toBe('forge_rate: invalid stars');
    expect(validateForge({ type: 'forge_rate', id: 'abc123', stars: 2.5 })).toBe('forge_rate: invalid stars');
    expect(validateForge({ type: 'forge_rate', id: 'AB', stars: 3 })).toBe('forge_rate: invalid id');
  });
  it('checks forge_played', () => {
    expect(validateForge({ type: 'forge_played', ids: ['abc123'] })).toBeNull();
    expect(validateForge({ type: 'forge_played', ids: [] })).toBe('forge_played: invalid ids');
    expect(validateForge({ type: 'forge_played', ids: new Array(9).fill('abc123') })).toBe('forge_played: invalid ids');
    expect(validateForge({ type: 'forge_played', ids: ['x'] })).toBe('forge_played: invalid ids');
  });
  it('checks sort and theme', () => {
    expect(validateForge({ type: 'forge_browse', sort: 'best' })).toBeNull();
    expect(validateForge({ type: 'forge_browse', sort: 'theme' })).toBeNull();
    expect(validateForge({ type: 'forge_browse', sort: 'worst' })).toBe('forge_browse: invalid sort');
    expect(validateForge({ type: 'forge_publish', mod: 'x', theme: true })).toBeNull();
    expect(validateForge({ type: 'forge_publish', mod: 'x', theme: 'yes' })).toBe('forge_publish: invalid theme');
  });
});

describe('remix credits', () => {
  it('reads one credit or a list and cleans it', () => {
    expect(cleanCredits({ id: 'orig01', name: 'Old Pack', author: 'Ana' })).toEqual([{ id: 'orig01', name: 'Old Pack', author: 'Ana' }]);
    expect(cleanCredits([{ id: 'orig01', name: '' }, { id: 'orig01' }, { id: 'BAD!' }, 5])).toEqual([{ id: 'orig01', name: 'Forge mod', author: '' }]);
    expect(cleanCredits(new Array(9).fill(0).map((_, i) => ({ id: 'orig0' + i })))).toHaveLength(4);
  });
  it('drops a credit to itself', () => {
    const c = checkMod(mod({ remix: [{ id: 'abc123', name: 'Me' }, { id: 'orig01', name: 'Old', author: 'Ana' }] }));
    expect(c.ok && c.remix).toEqual([{ id: 'orig01', name: 'Old', author: 'Ana' }]);
  });
});

describe('weekly theme', () => {
  it('moves to the next theme every week and counts the time left', () => {
    const a = themeInfo(WEEK0);
    const b = themeInfo(WEEK0 + FORGE_WEEK_MS);
    expect(a.week).toBe(10);
    expect(b.week).toBe(11);
    expect(a.key).toBe(FORGE_THEMES[10 % FORGE_THEMES.length].key);
    expect(b.last?.key).toBe(a.key);
    expect(a.left).toBe(7 * 24 * 3600 - 3600);
    expect(forgeWeek(FORGE_WEEK_EPOCH - 1)).toBe(-1);
    expect(themeInfo(FORGE_WEEK_EPOCH - 1).key).toBe(FORGE_THEMES[FORGE_THEMES.length - 1].key);
  });
});

for (const { name, make } of boards()) {
  describe(`ForgeBoard social (${name})`, () => {
    it('keeps old rows working with zero ratings', async () => {
      const { b } = make();
      expect((await b.publish(K1, mod())).ok).toBe(true);
      const r = await b.browse(K2);
      expect(r.mods[0]).toMatchObject({ id: 'abc123', rating: 0, votes: 0, plays: 0, downloads: 0 });
      expect(r.mods[0].remix).toBeUndefined();
      expect(r.sort).toBe('new');
      expect(r.theme?.week).toBe(10);
      const got = await b.get(K2, 'abc123');
      expect(got.ok && got.mod).toBe(mod());
    });

    it('takes one rating per player and lets them change it', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod());
      await b.played(K2, ['abc123']);
      await b.played(K3, ['abc123']);
      expect(await b.rate(K2, 'abc123', 5)).toEqual({ ok: true, stars: 5, rating: 5, votes: 1 });
      expect(await b.rate(K2, 'abc123', 4)).toEqual({ ok: false, reason: 'too_soon' });
      clock.t += 2000;
      expect(await b.rate(K2, 'abc123', 3)).toEqual({ ok: true, stars: 3, rating: 3, votes: 1 });
      clock.t += 2000;
      expect(await b.rate(K2, 'abc123', 3)).toEqual({ ok: true, stars: 3, rating: 3, votes: 1 });
      expect(await b.rate(K3, 'abc123', 4)).toEqual({ ok: true, stars: 4, rating: 3.5, votes: 2 });
      const row = (await b.browse(K2)).mods[0];
      expect(row).toMatchObject({ rating: 3.5, votes: 2, my: 3 });
      expect((await b.browse(K4)).mods[0].my).toBeUndefined();
    });

    it('counts a rating from an old key of the same player once', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod());
      await b.played(K2, ['abc123']);
      await b.rate(K2, 'abc123', 5);
      clock.t += 2000;
      expect(await b.rate(K3, 'abc123', 1, false, [K2])).toEqual({ ok: true, stars: 1, rating: 1, votes: 1 });
      expect((await b.browse(K3, 1, '', false, [K2])).mods[0].my).toBe(1);
    });

    it('refuses own, bot, keyless and gone ratings', async () => {
      const { b } = make();
      await b.publish(K1, mod());
      expect(await b.rate(K1, 'abc123', 5)).toEqual({ ok: false, reason: 'own' });
      expect(await b.rate(K4, 'abc123', 5, false, [K1])).toEqual({ ok: false, reason: 'own' });
      expect(await b.rate(K2, 'abc123', 5, true)).toEqual({ ok: false, reason: 'bot' });
      expect(await b.rate(undefined, 'abc123', 5)).toEqual({ ok: false, reason: 'no_key' });
      expect(await b.rate(K3, 'zzz999', 5)).toEqual({ ok: false, reason: 'gone' });
      expect(await b.rate(K5, 'abc123', 9)).toEqual({ ok: false, reason: 'bad_stars' });
    });

    it('lets only players who played a mod rate it', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod());
      expect((await b.browse(K2)).mods[0].played).toBeUndefined();
      expect(await b.rate(K2, 'abc123', 5)).toEqual({ ok: false, reason: 'not_played' });
      expect((await b.browse(K2)).mods[0]).toMatchObject({ votes: 0, rating: 0 });
      await b.get(K2, 'abc123');
      expect(await b.rate(K2, 'abc123', 5)).toEqual({ ok: false, reason: 'not_played' });
      expect(await b.played(K2, ['abc123'])).toEqual({ ok: true, counted: 1 });
      expect((await b.browse(K2)).mods[0].played).toBe(true);
      expect((await b.browse(K3)).mods[0].played).toBeUndefined();
      expect(await b.rate(K2, 'abc123', 5)).toEqual({ ok: true, stars: 5, rating: 5, votes: 1 });
      expect(await b.rate(K3, 'abc123', 1)).toEqual({ ok: false, reason: 'not_played' });
      expect(await b.rate(K4, 'abc123', 2, false, [K2])).toEqual({ ok: true, stars: 2, rating: 2, votes: 1 });
      expect((await b.browse(K4, 1, '', false, [K2])).mods[0]).toMatchObject({ played: true, my: 2 });
      clock.t += 2000;
      expect(await b.rate(K2, 'abc123', 4)).toEqual({ ok: true, stars: 4, rating: 4, votes: 1 });
      await b.played(K1, ['abc123']);
      expect(await b.rate(K1, 'abc123', 5)).toEqual({ ok: false, reason: 'own' });
    });

    it('does not mark a refused rating as the last one', async () => {
      const { b } = make();
      await b.publish(K1, mod());
      expect(await b.rate(K2, 'abc123', 5)).toEqual({ ok: false, reason: 'not_played' });
      await b.played(K2, ['abc123']);
      expect(await b.rate(K2, 'abc123', 5)).toMatchObject({ ok: true, votes: 1 });
    });

    it('sorts by best with a fair prior and by most played', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod({ id: 'one111', name: 'One' }));
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ id: 'two222', name: 'Two' }));
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ id: 'thr333', name: 'Three' }));
      for (const k of [K2, K3, K4, K5]) { await b.played(k, ['one111', 'two222', 'thr333']); }
      clock.t += 2000;
      await b.rate(K2, 'one111', 5);
      await b.rate(K3, 'two222', 5);
      await b.rate(K4, 'two222', 5);
      await b.rate(K5, 'thr333', 1);
      const best = await b.browse(K2, 1, '', false, [], 'best');
      expect(best.mods.map(m => m.id)).toEqual(['two222', 'one111', 'thr333']);
      expect(best.sort).toBe('best');
      const K6 = 'F'.repeat(24);
      const K7 = 'G'.repeat(24);
      expect(await b.played(K6, ['thr333', 'one111', 'thr333'])).toEqual({ ok: true, counted: 2 });
      expect(await b.played(K6, ['thr333'])).toEqual({ ok: false, counted: 0, reason: 'too_soon' });
      clock.t += 2000;
      expect(await b.played(K6, ['thr333'])).toEqual({ ok: true, counted: 0 });
      expect(await b.played(K7, ['thr333'])).toEqual({ ok: true, counted: 1 });
      expect(await b.played(K1, ['thr333'])).toEqual({ ok: true, counted: 0 });
      expect(await b.played(K4, ['zzz999'])).toEqual({ ok: true, counted: 0 });
      const played = await b.browse(K2, 1, '', false, [], 'played');
      expect(played.mods.map(m => [m.id, m.plays])).toEqual([['thr333', 6], ['one111', 5], ['two222', 4]]);
      expect((await b.browse(K1, 1, '', true, [], 'best')).sort).toBe('new');
    });

    it('keeps the remix credit from the server copy of the original', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod({ id: 'orig01', name: 'Old Pack', author: 'Ana' }));
      clock.t += FORGE_PUBLISH_GAP_MS;
      expect((await b.publish(K2, mod({ id: 'new001', name: 'Old Pack Remix', author: 'Bo', remix: [{ id: 'orig01', name: 'Fake', author: 'Liar' }, { id: 'gone01', name: 'Lost', author: 'Cy' }] }))).ok).toBe(true);
      clock.t += FORGE_PUBLISH_GAP_MS;
      expect((await b.publish(K1, mod({ id: 'self01', name: 'Mine Again', remix: { id: 'orig01', name: 'Old Pack', author: 'Ana' } }))).ok).toBe(true);
      const rows = (await b.browse(K3)).mods;
      const remix = rows.find(m => m.id === 'new001');
      expect(remix?.remix).toEqual([{ id: 'orig01', name: 'Old Pack', author: 'Ana' }, { id: 'gone01', name: 'Lost', author: 'Cy' }]);
      expect(rows.find(m => m.id === 'orig01')?.remixes).toBe(1);
      expect(rows.find(m => m.id === 'self01')?.remix).toBeUndefined();
    });

    it('runs a weekly theme and features last week best', async () => {
      const { b, clock } = make();
      expect((await b.publish(K1, mod({ id: 'aaa111', name: 'A' }), false, [], true))).toMatchObject({ ok: true, theme: true });
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ id: 'bbb222', name: 'B' }), false, [], true);
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ id: 'ccc333', name: 'C' }), false, [], true);
      clock.t += FORGE_PUBLISH_GAP_MS;
      expect(await b.publish(K1, mod({ id: 'ddd444', name: 'D' }), false, [], true)).toEqual({ ok: false, reason: 'theme_full' });
      await b.publish(K2, mod({ id: 'eee555', name: 'E' }));
      await b.played(K3, ['bbb222']);
      await b.played(K4, ['aaa111']);
      await b.rate(K3, 'bbb222', 5);
      await b.rate(K4, 'aaa111', 2);
      let r = await b.browse(K3, 1, '', false, [], 'theme');
      expect(r.mods.map(m => m.id)).toEqual(['bbb222', 'ccc333', 'aaa111']);
      expect(r.mods.every(m => m.theme === true && m.featured === undefined)).toBe(true);
      clock.t += FORGE_WEEK_MS;
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K2, mod({ id: 'eee555', name: 'E' }), false, [], true);
      r = await b.browse(K3, 1, '', false, [], 'theme');
      expect(r.theme?.week).toBe(11);
      expect(r.mods.map(m => [m.id, m.featured ?? 0])).toEqual([['bbb222', 1], ['aaa111', 2], ['eee555', 0]]);
      expect(r.mods[0].theme).toBeUndefined();
      expect(r.pages).toBe(1);
      expect(r.mods.length).toBeLessThanOrEqual(FORGE_THEME_PER_PAGE);
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ id: 'bbb222', name: 'B v2', version: 2 }));
      r = await b.browse(K3, 1, '', false, [], 'theme');
      expect(r.mods[0]).toMatchObject({ id: 'bbb222', featured: 1, rating: 5, votes: 1 });
    });

    it('drops ratings and plays when the owner removes a mod', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod());
      await b.played(K2, ['abc123']);
      await b.rate(K2, 'abc123', 4);
      expect((await b.unpublish(K1, 'abc123')).ok).toBe(true);
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod());
      expect((await b.browse(K2)).mods[0]).toMatchObject({ votes: 0, plays: 0 });
      expect((await b.browse(K2)).mods[0].my).toBeUndefined();
      expect((await b.browse(K2)).mods[0].played).toBeUndefined();
    });

    it('keeps counts when downloads and updates rewrite the row', async () => {
      const { b, clock } = make();
      await b.publish(K1, mod());
      await b.played(K2, ['abc123']);
      await b.rate(K2, 'abc123', 4);
      await b.played(K3, ['abc123']);
      await b.get(K4, 'abc123');
      clock.t += FORGE_PUBLISH_GAP_MS;
      await b.publish(K1, mod({ version: 2 }));
      expect((await b.browse(K5)).mods[0]).toMatchObject({ votes: 1, rating: 4, plays: 2, downloads: 1, version: 2 });
    });
  });
}

describe('D1 schema upgrade', () => {
  it('adds the new columns to an old forge_mods table and keeps its rows', async () => {
    const d1 = sqliteD1();
    d1.db.exec(`CREATE TABLE forge_mods (id TEXT PRIMARY KEY, owner TEXT NOT NULL, name TEXT NOT NULL, author TEXT NOT NULL, about TEXT NOT NULL,
      version INTEGER NOT NULL, summary TEXT NOT NULL, size INTEGER NOT NULL, raw TEXT NOT NULL, at INTEGER NOT NULL, updated INTEGER NOT NULL,
      downloads INTEGER NOT NULL, reports TEXT NOT NULL, hidden INTEGER NOT NULL)`);
    d1.db.prepare(`INSERT INTO forge_mods VALUES ('old001', ?, 'Old', 'Ana', '[]', 3, '{"joker":1}', 10, ?, 1, 2, 7, '[]', 0)`).run(K1, mod({ id: 'old001' }));
    const b = new ForgeBoard(new D1ForgeStore(d1), { now: () => WEEK0 });
    const r = await b.browse(K2);
    expect(r.mods[0]).toMatchObject({ id: 'old001', version: 3, downloads: 7, rating: 0, votes: 0, plays: 0 });
    await b.played(K2, ['old001']);
    expect(await b.rate(K2, 'old001', 4)).toMatchObject({ ok: true, votes: 1 });
    const again = new ForgeBoard(new D1ForgeStore(d1), { now: () => WEEK0 });
    expect((await again.browse(K3)).mods[0]).toMatchObject({ rating: 4, votes: 1 });
    expect((await again.unpublish(K1, 'old001')).ok).toBe(true);
  });
});

describe('forge handlers for ratings and plays', () => {
  it('answers forge_rated and forge_counted', async () => {
    const old = forgeBoard;
    setForgeBoard(new ForgeBoard(new MemoryForgeStore()));
    const sent: Record<string, unknown>[] = [];
    const h = forgeHandlers<string>({ keyOf: (ws) => ws, isBot: () => false, send: (_ws, d) => { sent.push(d as Record<string, unknown>); } });
    await forgeBoard.publish(K1, mod());
    h.forge_rate(K4, { type: 'forge_rate', id: 'abc123', stars: 4 });
    await forgeBoard.played(K2, ['abc123']);
    h.forge_rate(K2, { type: 'forge_rate', id: 'abc123', stars: 4 });
    h.forge_played(K3, { type: 'forge_played', ids: ['abc123'] });
    h.forge_browse(K2, { type: 'forge_browse', sort: 'played' });
    for (let i = 0; i < 20 && sent.length < 4; i++) await new Promise(r => setTimeout(r, 5));
    expect(sent.find(d => d.type === 'forge_rated' && d.ok === false)).toMatchObject({ id: 'abc123', reason: 'not_played' });
    expect(sent.find(d => d.type === 'forge_rated' && d.ok === true)).toMatchObject({ id: 'abc123', ok: true, stars: 4, votes: 1 });
    expect(sent.find(d => d.type === 'forge_counted')).toMatchObject({ ok: true, counted: 1 });
    expect(sent.find(d => d.type === 'forge_list')).toMatchObject({ sort: 'played' });
    setForgeBoard(old);
  });
});
