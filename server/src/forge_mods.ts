export const FORGE_TYPES = ['forge_publish', 'forge_browse', 'forge_get', 'forge_report', 'forge_unpublish', 'forge_rate', 'forge_played'];
export const FORGE_MAX_BYTES = 512 * 1024;
export const FORGE_MAX_ITEMS = 60;
export const FORGE_MAX_FILE_B64 = 88 * 1024;
export const FORGE_PER_PAGE = 4;
export const FORGE_MAX_PER_OWNER = 20;
export const FORGE_HIDE_AT = 3;
export const FORGE_PUBLISH_GAP_MS = 20_000;
export const FORGE_MAX_V = 99;
export const FORGE_MAX_ALT_KEYS = 8;
export const FORGE_THEME_PER_PAGE = 3;
export const FORGE_FEATURED = 3;
export const FORGE_THEME_MAX_PER_OWNER = 3;
export const FORGE_RATE_GAP_MS = 1_500;
export const FORGE_MAX_REMIX = 4;
export const FORGE_MAX_PLAYED = 8;
export const FORGE_WEEK_MS = 7 * 24 * 3600 * 1000;
export const FORGE_WEEK_EPOCH = Date.UTC(2026, 0, 5);
export const FORGE_SORTS = ['new', 'best', 'played', 'theme'];
export const FORGE_THEMES: { key: string; title: string }[] = [
  { key: 'hearts', title: 'Hearts only' },
  { key: 'money', title: 'Money makers' },
  { key: 'faces', title: 'Face cards' },
  { key: 'grow', title: 'Jokers that grow' },
  { key: 'bosses', title: 'Boss Blinds' },
  { key: 'retrigger', title: 'Retriggers' },
  { key: 'suits', title: 'New suits' },
  { key: 'decks', title: 'Decks and Challenges' },
  { key: 'luck', title: 'Risk and luck' },
  { key: 'consumables', title: 'Tarots and Spectrals' },
  { key: 'fusions', title: 'Fusions' },
  { key: 'art', title: 'Best art' },
];

const ID_RE = /^[a-z0-9]{4,8}$/;
const PKEY_RE = /^[A-Za-z0-9]{24}$/;
const FILE_KEY_RE = /^[A-Za-z0-9_]{1,40}$/;
const B64_RE = /^[A-Za-z0-9+/]*={0,2}$/;
const KINDS = new Set(['joker', 'tarot', 'planet', 'spectral', 'voucher', 'enhancement', 'seal', 'edition', 'tag', 'blind', 'stake', 'deck', 'booster', 'collab', 'suit', 'hand', 'ctype', 'challenge', 'rarity', 'sticker', 'fusion']);
const REASONS = new Set(['broken', 'rude', 'stolen', 'other']);

export interface ForgeEntry {
  id: string;
  owner: string;
  name: string;
  author: string;
  about: string[];
  version: number;
  summary: Record<string, number>;
  size: number;
  raw: string;
  at: number;
  updated: number;
  downloads: number;
  reports: string[];
  hidden: boolean;
  remix: Credit[];
  theme: number;
  stars: number;
  votes: number;
  plays: number;
}

export interface Credit { id: string; name: string; author: string }

export interface ForgeRow {
  id: string; name: string; author: string; about: string[]; version: number;
  summary: Record<string, number>; size: number; downloads: number; updated: number; mine?: boolean;
  rating: number; votes: number; plays: number; remix?: Credit[]; remixes?: number; my?: number; featured?: number; theme?: boolean; played?: boolean;
}

export interface ThemeInfo { week: number; key: string; title: string; left: number; last?: { key: string; title: string } }

export interface ForgeStore {
  readonly kind: string;
  init(): Promise<void>;
  get(id: string): Promise<ForgeEntry | null>;
  put(e: ForgeEntry): Promise<void>;
  remove(id: string): Promise<void>;
  list(): Promise<ForgeEntry[]>;
  ratings(ids: string[], keys: string[]): Promise<Map<string, { pkey: string; stars: number }>>;
  rate(id: string, pkey: string, stars: number, prev: { pkey: string; stars: number } | null, at: number): Promise<void>;
  played(id: string, keys: string[]): Promise<boolean>;
  playedOf(ids: string[], keys: string[]): Promise<Set<string>>;
  play(id: string, pkey: string, at: number): Promise<void>;
}

function copyEntry(e: ForgeEntry): ForgeEntry { return { ...e, reports: [...e.reports], remix: e.remix.map(c => ({ ...c })) }; }

export class MemoryForgeStore implements ForgeStore {
  readonly kind = 'memory';
  rows = new Map<string, ForgeEntry>();
  votes = new Map<string, Map<string, number>>();
  plays = new Map<string, Set<string>>();
  async init(): Promise<void> {}
  async get(id: string): Promise<ForgeEntry | null> { const e = this.rows.get(id); return e ? copyEntry(e) : null; }
  async put(e: ForgeEntry): Promise<void> {
    const old = this.rows.get(e.id);
    this.rows.set(e.id, { ...copyEntry(e), stars: old ? old.stars : 0, votes: old ? old.votes : 0, plays: old ? old.plays : 0 });
  }
  async remove(id: string): Promise<void> { this.rows.delete(id); this.votes.delete(id); this.plays.delete(id); }
  async list(): Promise<ForgeEntry[]> { return [...this.rows.values()].map(e => ({ ...copyEntry(e), raw: '' })); }
  async ratings(ids: string[], keys: string[]): Promise<Map<string, { pkey: string; stars: number }>> {
    const out = new Map<string, { pkey: string; stars: number }>();
    for (const id of ids) {
      const v = this.votes.get(id);
      for (const k of keys) { const s = v?.get(k); if (s !== undefined) { out.set(id, { pkey: k, stars: s }); break; } }
    }
    return out;
  }
  async rate(id: string, pkey: string, stars: number, prev: { pkey: string; stars: number } | null, _at: number): Promise<void> {
    const e = this.rows.get(id);
    if (!e) return;
    const v = this.votes.get(id) ?? new Map<string, number>();
    this.votes.set(id, v);
    if (prev) { v.set(prev.pkey, stars); e.stars += stars - prev.stars; } else { v.set(pkey, stars); e.stars += stars; e.votes += 1; }
  }
  async played(id: string, keys: string[]): Promise<boolean> { const p = this.plays.get(id); return !!p && keys.some(k => p.has(k)); }
  async playedOf(ids: string[], keys: string[]): Promise<Set<string>> {
    const out = new Set<string>();
    for (const id of ids) if (await this.played(id, keys)) out.add(id);
    return out;
  }
  async play(id: string, pkey: string, _at: number): Promise<void> {
    const e = this.rows.get(id);
    if (!e) return;
    const p = this.plays.get(id) ?? new Set<string>();
    this.plays.set(id, p);
    if (!p.has(pkey)) { p.add(pkey); e.plays += 1; }
  }
}

export interface D1Like {
  kind?: string;
  query(sql: string, params?: unknown[]): Promise<Record<string, unknown>[]>;
  write(sql: string, params: unknown[]): void;
}

export const FORGE_SCHEMA = [
  `CREATE TABLE IF NOT EXISTS forge_mods (id TEXT PRIMARY KEY, owner TEXT NOT NULL, name TEXT NOT NULL, author TEXT NOT NULL, about TEXT NOT NULL,
    version INTEGER NOT NULL, summary TEXT NOT NULL, size INTEGER NOT NULL, raw TEXT NOT NULL, at INTEGER NOT NULL, updated INTEGER NOT NULL,
    downloads INTEGER NOT NULL, reports TEXT NOT NULL, hidden INTEGER NOT NULL)`,
];

export const FORGE_ALTER = [
  `ALTER TABLE forge_mods ADD COLUMN remix TEXT NOT NULL DEFAULT '[]'`,
  `ALTER TABLE forge_mods ADD COLUMN theme INTEGER NOT NULL DEFAULT 0`,
  `ALTER TABLE forge_mods ADD COLUMN stars INTEGER NOT NULL DEFAULT 0`,
  `ALTER TABLE forge_mods ADD COLUMN votes INTEGER NOT NULL DEFAULT 0`,
  `ALTER TABLE forge_mods ADD COLUMN plays INTEGER NOT NULL DEFAULT 0`,
];

export const FORGE_SOCIAL_SCHEMA = [
  `CREATE TABLE IF NOT EXISTS forge_ratings (mod_id TEXT NOT NULL, pkey TEXT NOT NULL, stars INTEGER NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (mod_id, pkey))`,
  `CREATE TABLE IF NOT EXISTS forge_plays (mod_id TEXT NOT NULL, pkey TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (mod_id, pkey))`,
];

function parseJson<T>(s: unknown, def: T): T {
  try { return typeof s === 'string' ? JSON.parse(s) as T : def; } catch { return def; }
}

function toEntry(r: Record<string, unknown>): ForgeEntry {
  return {
    id: String(r.id), owner: String(r.owner), name: String(r.name ?? ''), author: String(r.author ?? ''), about: parseJson<string[]>(r.about, []),
    version: Number(r.version) || 1, summary: parseJson<Record<string, number>>(r.summary, {}), size: Number(r.size) || 0, raw: String(r.raw ?? ''),
    at: Number(r.at) || 0, updated: Number(r.updated) || 0, downloads: Number(r.downloads) || 0, reports: parseJson<string[]>(r.reports, []), hidden: Number(r.hidden) === 1,
    remix: cleanCredits(parseJson<unknown>(r.remix, [])), theme: Number(r.theme) || 0, stars: Number(r.stars) || 0, votes: Number(r.votes) || 0, plays: Number(r.plays) || 0,
  };
}

function marks(n: number): string { return new Array(n).fill('?').join(', '); }

export class D1ForgeStore implements ForgeStore {
  readonly kind = 'd1';
  constructor(private d1: D1Like) {}
  async init(): Promise<void> {
    for (const sql of FORGE_SCHEMA) await this.d1.query(sql);
    for (const sql of FORGE_ALTER) await this.d1.query(sql).catch(() => undefined);
    for (const sql of FORGE_SOCIAL_SCHEMA) await this.d1.query(sql);
  }
  async get(id: string): Promise<ForgeEntry | null> {
    const rows = await this.d1.query('SELECT * FROM forge_mods WHERE id = ?', [id]);
    return rows[0] ? toEntry(rows[0]) : null;
  }
  async put(e: ForgeEntry): Promise<void> {
    await this.d1.query(`INSERT INTO forge_mods (id, owner, name, author, about, version, summary, size, raw, at, updated, downloads, reports, hidden, remix, theme)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT (id) DO UPDATE SET owner = excluded.owner, name = excluded.name, author = excluded.author,
      about = excluded.about, version = excluded.version, summary = excluded.summary, size = excluded.size, raw = excluded.raw, updated = excluded.updated,
      downloads = excluded.downloads, reports = excluded.reports, hidden = excluded.hidden, remix = excluded.remix, theme = excluded.theme`,
    [e.id, e.owner, e.name, e.author, JSON.stringify(e.about), e.version, JSON.stringify(e.summary), e.size, e.raw, e.at, e.updated, e.downloads, JSON.stringify(e.reports), e.hidden ? 1 : 0, JSON.stringify(e.remix), e.theme]);
  }
  async remove(id: string): Promise<void> {
    await this.d1.query('DELETE FROM forge_mods WHERE id = ?', [id]);
    await this.d1.query('DELETE FROM forge_ratings WHERE mod_id = ?', [id]);
    await this.d1.query('DELETE FROM forge_plays WHERE mod_id = ?', [id]);
  }
  async list(): Promise<ForgeEntry[]> {
    const rows = await this.d1.query(`SELECT id, owner, name, author, about, version, summary, size, '' AS raw, at, updated, downloads, reports, hidden, remix, theme, stars, votes, plays FROM forge_mods`);
    return rows.map(toEntry);
  }
  async ratings(ids: string[], keys: string[]): Promise<Map<string, { pkey: string; stars: number }>> {
    const out = new Map<string, { pkey: string; stars: number }>();
    if (ids.length === 0 || keys.length === 0) return out;
    const rows = await this.d1.query(`SELECT mod_id, pkey, stars FROM forge_ratings WHERE mod_id IN (${marks(ids.length)}) AND pkey IN (${marks(keys.length)})`, [...ids, ...keys]);
    for (const k of keys) for (const r of rows) if (r.pkey === k && !out.has(String(r.mod_id))) out.set(String(r.mod_id), { pkey: k, stars: Number(r.stars) || 0 });
    return out;
  }
  async rate(id: string, pkey: string, stars: number, prev: { pkey: string; stars: number } | null, at: number): Promise<void> {
    if (prev) {
      await this.d1.query('UPDATE forge_ratings SET stars = ?, at = ? WHERE mod_id = ? AND pkey = ?', [stars, at, id, prev.pkey]);
      await this.d1.query('UPDATE forge_mods SET stars = stars + ? WHERE id = ?', [stars - prev.stars, id]);
    } else {
      await this.d1.query('INSERT INTO forge_ratings (mod_id, pkey, stars, at) VALUES (?, ?, ?, ?)', [id, pkey, stars, at]);
      await this.d1.query('UPDATE forge_mods SET stars = stars + ?, votes = votes + 1 WHERE id = ?', [stars, id]);
    }
  }
  async played(id: string, keys: string[]): Promise<boolean> {
    if (keys.length === 0) return false;
    const rows = await this.d1.query(`SELECT pkey FROM forge_plays WHERE mod_id = ? AND pkey IN (${marks(keys.length)}) LIMIT 1`, [id, ...keys]);
    return rows.length > 0;
  }
  async playedOf(ids: string[], keys: string[]): Promise<Set<string>> {
    const out = new Set<string>();
    if (ids.length === 0 || keys.length === 0) return out;
    const rows = await this.d1.query(`SELECT DISTINCT mod_id FROM forge_plays WHERE mod_id IN (${marks(ids.length)}) AND pkey IN (${marks(keys.length)})`, [...ids, ...keys]);
    for (const r of rows) out.add(String(r.mod_id));
    return out;
  }
  async play(id: string, pkey: string, at: number): Promise<void> {
    await this.d1.query('INSERT INTO forge_plays (mod_id, pkey, at) VALUES (?, ?, ?)', [id, pkey, at]);
    await this.d1.query('UPDATE forge_mods SET plays = plays + 1 WHERE id = ?', [id]);
  }
}

export function forgeStoreFor(store: unknown): ForgeStore {
  const s = store as D1Like | null;
  if (s && s.kind === 'd1' && typeof s.query === 'function' && typeof s.write === 'function') return new D1ForgeStore(s);
  return new MemoryForgeStore();
}

function isInt(v: unknown, lo: number, hi: number): boolean {
  return typeof v === 'number' && Number.isInteger(v) && v >= lo && v <= hi;
}

export function validateForge(msg: Record<string, unknown>): string | null {
  const t = msg.type;
  if (typeof t !== 'string' || !FORGE_TYPES.includes(t)) return null;
  if (t === 'forge_publish') {
    if (typeof msg.mod !== 'string' || msg.mod.length === 0) return 'forge_publish: missing mod';
    if (msg.mod.length > FORGE_MAX_BYTES) return 'forge_publish: too big';
  }
  if (t === 'forge_browse') {
    if (msg.page !== undefined && !isInt(msg.page, 1, 10000)) return 'forge_browse: invalid page';
    if (msg.q !== undefined && (typeof msg.q !== 'string' || msg.q.length > 24)) return 'forge_browse: invalid q';
    if (msg.mine !== undefined && typeof msg.mine !== 'boolean') return 'forge_browse: invalid mine';
    if (msg.sort !== undefined && (typeof msg.sort !== 'string' || !FORGE_SORTS.includes(msg.sort))) return 'forge_browse: invalid sort';
  }
  if (t === 'forge_publish' && msg.theme !== undefined && typeof msg.theme !== 'boolean') return 'forge_publish: invalid theme';
  if (t === 'forge_rate' && !isInt(msg.stars, 1, 5)) return 'forge_rate: invalid stars';
  if (t === 'forge_played' && (!Array.isArray(msg.ids) || msg.ids.length === 0 || msg.ids.length > FORGE_MAX_PLAYED || !msg.ids.every(i => typeof i === 'string' && ID_RE.test(i)))) return 'forge_played: invalid ids';
  if (t === 'forge_get' || t === 'forge_report' || t === 'forge_unpublish' || t === 'forge_rate') {
    if (typeof msg.id !== 'string' || !ID_RE.test(msg.id)) return `${t}: invalid id`;
  }
  if (t === 'forge_report' && (typeof msg.reason !== 'string' || !REASONS.has(msg.reason))) return 'forge_report: invalid reason';
  if (msg.keys !== undefined && (!Array.isArray(msg.keys) || msg.keys.length > FORGE_MAX_ALT_KEYS || !msg.keys.every(k => typeof k === 'string' && PKEY_RE.test(k)))) return `${t}: invalid keys`;
  return null;
}

function clean(s: unknown, max: number): string {
  return String(typeof s === 'string' ? s : '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max);
}

export function cleanCredits(v: unknown): Credit[] {
  const list = Array.isArray(v) ? v : (v && typeof v === 'object' ? [v] : []);
  const out: Credit[] = [];
  for (const c of list) {
    if (!c || typeof c !== 'object' || Array.isArray(c)) continue;
    const r = c as Record<string, unknown>;
    if (typeof r.id !== 'string' || !ID_RE.test(r.id) || out.some(x => x.id === r.id)) continue;
    out.push({ id: r.id, name: clean(r.name, 24) || 'Forge mod', author: clean(r.author, 24) });
    if (out.length >= FORGE_MAX_REMIX) break;
  }
  return out;
}

export function forgeWeek(now: number): number { return Math.floor((now - FORGE_WEEK_EPOCH) / FORGE_WEEK_MS); }

export function themeOf(week: number): { key: string; title: string } {
  const n = FORGE_THEMES.length;
  return FORGE_THEMES[((week % n) + n) % n];
}

export function themeInfo(now: number): ThemeInfo {
  const week = forgeWeek(now);
  const t = themeOf(week);
  return { week, key: t.key, title: t.title, left: Math.max(0, Math.ceil((FORGE_WEEK_EPOCH + (week + 1) * FORGE_WEEK_MS - now) / 1000)), last: themeOf(week - 1) };
}

export function bestScore(e: { stars: number; votes: number }): number { return (e.stars + 6) / (e.votes + 2); }

export type Checked = { ok: true; id: string; name: string; author: string; about: string[]; version: number; summary: Record<string, number>; remix: Credit[] } | { ok: false; reason: string; why?: string };

function no(reason: string, why: string): Checked { return { ok: false, reason, why }; }

export function checkMod(raw: string): Checked {
  if (raw.length > FORGE_MAX_BYTES) return no('too_big', 'too_big');
  let t: Record<string, unknown>;
  try {
    const p = JSON.parse(raw) as unknown;
    if (!p || typeof p !== 'object' || Array.isArray(p)) return no('not_forge', 'not_json');
    t = p as Record<string, unknown>;
  } catch { return no('not_forge', 'not_json'); }
  if (t.format !== 'forgemod') return no('not_forge', 'bad_format');
  if (!isInt(t.v, 1, FORGE_MAX_V)) return no('not_forge', 'bad_version');
  if (typeof t.id !== 'string' || !ID_RE.test(t.id)) return no('not_forge', 'bad_id');
  const jokers = Array.isArray(t.jokers) ? t.jokers : [];
  const creations = Array.isArray(t.creations) ? t.creations : [];
  if (t.jokers !== undefined && !Array.isArray(t.jokers) && !(typeof t.jokers === 'object' && t.jokers && Object.keys(t.jokers).length === 0)) return no('not_forge', 'bad_jokers');
  if (t.creations !== undefined && !Array.isArray(t.creations) && !(typeof t.creations === 'object' && t.creations && Object.keys(t.creations).length === 0)) return no('not_forge', 'bad_creations');
  const n = jokers.length + creations.length;
  if (n === 0) return no('empty', 'empty');
  if (n > FORGE_MAX_ITEMS) return no('too_many', 'too_many');
  const summary: Record<string, number> = {};
  for (const j of jokers) {
    if (!j || typeof j !== 'object' || Array.isArray(j)) return no('not_forge', 'bad_joker');
    summary.joker = (summary.joker ?? 0) + 1;
  }
  for (const c of creations) {
    const kind = c && typeof c === 'object' ? (c as Record<string, unknown>).kind : undefined;
    if (typeof kind !== 'string' || !KINDS.has(kind) || kind === 'joker') return no('not_forge', 'bad_kind');
    summary[kind] = (summary[kind] ?? 0) + 1;
  }
  if (t.files !== undefined && t.files !== null) {
    if (typeof t.files !== 'object') return no('not_forge', 'bad_files');
    const entries = Array.isArray(t.files) ? [] : Object.entries(t.files as Record<string, unknown>);
    if (Array.isArray(t.files) && t.files.length > 0) return no('not_forge', 'bad_files');
    if (entries.length > 200) return no('too_many', 'too_many_files');
    for (const [k, v] of entries) {
      if (!FILE_KEY_RE.test(k)) return no('bad_art', 'bad_art_name');
      if (typeof v === 'string' && v.length > FORGE_MAX_FILE_B64) return no('bad_art', 'art_too_big');
      if (typeof v !== 'string' || v.length % 4 !== 0 || !B64_RE.test(v) || !v.startsWith('iVBORw0KGgo')) return no('bad_art', 'bad_art');
    }
  }
  const name = clean(t.name, 24) || 'Forge mod';
  const about = (Array.isArray(t.about) ? t.about : []).filter((l): l is string => typeof l === 'string').map(l => clean(l, 48)).filter(l => l !== '').slice(0, 2);
  const version = isInt(t.version, 1, 9999) ? Number(t.version) : 1;
  const remix = cleanCredits(t.remix).filter(c => c.id !== t.id);
  return { ok: true, id: t.id, name, author: clean(t.author, 24), about, version, summary, remix };
}

export interface ForgeDeps {
  now?: () => number;
  log?: (level: string, msg: string) => void;
}

export type PublishOut = { ok: true; id: string; version: number; updated: boolean; theme?: boolean } | { ok: false; reason: string; why?: string };
export interface ListOut { mods: ForgeRow[]; page: number; pages: number; total: number; sort?: string; theme?: ThemeInfo }
export type RateOut = { ok: true; stars: number; rating: number; votes: number } | { ok: false; reason: string };

export function altKeys(msg: Record<string, unknown>, pkey: string | undefined): string[] {
  if (!Array.isArray(msg.keys)) return [];
  const out: string[] = [];
  for (const k of msg.keys) {
    if (typeof k === 'string' && PKEY_RE.test(k) && k !== pkey && !out.includes(k)) out.push(k);
    if (out.length >= FORGE_MAX_ALT_KEYS) break;
  }
  return out;
}

export function ownsEntry(e: { owner: string }, pkey: string | undefined, alts: string[] = []): boolean {
  if (!pkey || !PKEY_RE.test(pkey)) return false;
  return e.owner === pkey || alts.includes(e.owner);
}

export class ForgeBoard {
  private ready: Promise<void> | null = null;
  private lastPublish = new Map<string, number>();
  private busy = new Set<string>();
  private lastRate = new Map<string, number>();
  private lastPlayed = new Map<string, number>();
  private rating = new Set<string>();
  constructor(readonly store: ForgeStore, private deps: ForgeDeps = {}) {}

  private now(): number { return this.deps.now ? this.deps.now() : Date.now(); }

  ensure(): Promise<void> {
    if (!this.ready) this.ready = this.store.init().catch(e => { this.ready = null; throw e; });
    return this.ready;
  }

  async publish(pkey: string | undefined, raw: string, bot = false, alts: string[] = [], theme = false): Promise<PublishOut> {
    if (bot) return { ok: false, reason: 'bot' };
    if (!pkey || !PKEY_RE.test(pkey)) return { ok: false, reason: 'no_key' };
    const c = checkMod(raw);
    if (!c.ok) return c;
    const last = this.lastPublish.get(pkey) ?? 0;
    if (this.now() - last < FORGE_PUBLISH_GAP_MS) return { ok: false, reason: 'too_soon' };
    await this.ensure();
    if (this.busy.has(c.id)) return { ok: false, reason: 'busy' };
    this.busy.add(c.id);
    try {
      const old = await this.store.get(c.id);
      if (old && !ownsEntry(old, pkey, alts)) return { ok: false, reason: 'taken' };
      const week = forgeWeek(this.now());
      if (!old || theme) {
        const all = (await this.store.list()).filter(e => ownsEntry(e, pkey, alts));
        if (!old && all.length >= FORGE_MAX_PER_OWNER) return { ok: false, reason: 'too_many_mods' };
        if (theme && all.filter(e => e.theme === week && e.id !== c.id).length >= FORGE_THEME_MAX_PER_OWNER) return { ok: false, reason: 'theme_full' };
      }
      const remix: Credit[] = [];
      for (const cr of c.remix) {
        const src = await this.store.get(cr.id);
        if (src && ownsEntry(src, pkey, alts)) continue;
        remix.push(src ? { id: src.id, name: src.name, author: src.author } : cr);
      }
      const t = this.now();
      const e: ForgeEntry = {
        id: c.id, owner: pkey, name: c.name, author: c.author, about: c.about, version: Math.max(c.version, old ? old.version : 1),
        summary: c.summary, size: raw.length, raw, at: old ? old.at : t, updated: t, downloads: old ? old.downloads : 0,
        reports: old ? old.reports : [], hidden: old ? old.hidden : false,
        remix, theme: theme ? week : (old ? old.theme : 0), stars: old ? old.stars : 0, votes: old ? old.votes : 0, plays: old ? old.plays : 0,
      };
      await this.store.put(e);
      this.lastPublish.set(pkey, t);
      this.deps.log?.('INFO', 'FORGE', `${old ? 'updated' : 'published'} ${e.id} "${e.name}" ${e.size} bytes${old && old.owner !== pkey ? ' (owner key moved)' : ''}`);
      return e.theme === week ? { ok: true, id: e.id, version: e.version, updated: old !== null, theme: true } : { ok: true, id: e.id, version: e.version, updated: old !== null };
    } finally {
      this.busy.delete(c.id);
    }
  }

  async browse(pkey: string | undefined, page = 1, q = '', mineOnly = false, alts: string[] = [], sort = 'new'): Promise<ListOut> {
    await this.ensure();
    const query = q.trim().toLowerCase();
    const info = themeInfo(this.now());
    const all = await this.store.list();
    const remixes = new Map<string, number>();
    for (const e of all) if (!e.hidden) for (const c of e.remix) remixes.set(c.id, (remixes.get(c.id) ?? 0) + 1);
    let list = all.filter(e => (!e.hidden || ownsEntry(e, pkey, alts)));
    if (mineOnly) list = list.filter(e => ownsEntry(e, pkey, alts));
    if (query) list = list.filter(e => e.name.toLowerCase().includes(query) || e.author.toLowerCase().includes(query));
    const byNew = (a: ForgeEntry, b: ForgeEntry) => b.updated - a.updated || (a.id < b.id ? -1 : 1);
    const byBest = (a: ForgeEntry, b: ForgeEntry) => bestScore(b) - bestScore(a) || b.votes - a.votes || byNew(a, b);
    const mode = mineOnly ? 'new' : (FORGE_SORTS.includes(sort) ? sort : 'new');
    const featured = new Map<string, number>();
    if (mode === 'theme') {
      const top = all.filter(e => !e.hidden && e.theme === info.week - 1 && e.votes > 0).sort(byBest).slice(0, FORGE_FEATURED);
      top.forEach((e, i) => featured.set(e.id, i + 1));
      list = [...top, ...list.filter(e => e.theme === info.week && !featured.has(e.id)).sort(byBest)];
    } else if (mode === 'best') {
      list.sort(byBest);
    } else if (mode === 'played') {
      list.sort((a, b) => b.plays - a.plays || b.downloads - a.downloads || byNew(a, b));
    } else {
      list.sort(byNew);
    }
    const per = mode === 'theme' ? FORGE_THEME_PER_PAGE : FORGE_PER_PAGE;
    const pages = Math.max(1, Math.ceil(list.length / per));
    const p = Math.min(Math.max(1, page), pages);
    const slice = list.slice((p - 1) * per, p * per);
    const keys = pkey && PKEY_RE.test(pkey) ? [pkey, ...alts] : [];
    const mine = slice.length > 0 && keys.length > 0 ? await this.store.ratings(slice.map(e => e.id), keys).catch(() => new Map<string, { pkey: string; stars: number }>()) : new Map<string, { pkey: string; stars: number }>();
    const done = slice.length > 0 && keys.length > 0 ? await this.store.playedOf(slice.map(e => e.id), keys).catch(() => new Set<string>()) : new Set<string>();
    const mods = slice.map(e => {
      const r: ForgeRow = {
        id: e.id, name: e.name, author: e.author, about: e.about, version: e.version, summary: e.summary, size: e.size, downloads: e.downloads, updated: e.updated,
        rating: e.votes > 0 ? Math.round(e.stars / e.votes * 10) / 10 : 0, votes: e.votes, plays: e.plays,
      };
      if (ownsEntry(e, pkey, alts)) r.mine = true;
      if (e.remix.length > 0) r.remix = e.remix;
      const n = remixes.get(e.id);
      if (n) r.remixes = n;
      const my = mine.get(e.id);
      if (my) r.my = my.stars;
      if (done.has(e.id)) r.played = true;
      const f = featured.get(e.id);
      if (f) r.featured = f;
      if (e.theme === info.week) r.theme = true;
      return r;
    });
    return { mods, page: p, pages, total: list.length, sort: mode, theme: info };
  }

  async rate(pkey: string | undefined, id: string, stars: number, bot = false, alts: string[] = []): Promise<RateOut> {
    if (bot) return { ok: false, reason: 'bot' };
    if (!pkey || !PKEY_RE.test(pkey)) return { ok: false, reason: 'no_key' };
    if (!Number.isInteger(stars) || stars < 1 || stars > 5) return { ok: false, reason: 'bad_stars' };
    if (this.now() - (this.lastRate.get(pkey) ?? -Infinity) < FORGE_RATE_GAP_MS || this.rating.has(pkey)) return { ok: false, reason: 'too_soon' };
    this.rating.add(pkey);
    try {
      await this.ensure();
      const e = await this.store.get(id);
      if (!e || e.hidden) return { ok: false, reason: 'gone' };
      if (ownsEntry(e, pkey, alts)) return { ok: false, reason: 'own' };
      if (!(await this.store.played(id, [pkey, ...alts]))) return { ok: false, reason: 'not_played' };
      const prev = (await this.store.ratings([id], [pkey, ...alts])).get(id) ?? null;
      this.lastRate.set(pkey, this.now());
      let total = e.stars, votes = e.votes;
      if (!prev || prev.stars !== stars) {
        await this.store.rate(id, pkey, stars, prev, this.now());
        total += stars - (prev ? prev.stars : 0);
        if (!prev) votes += 1;
      }
      return { ok: true, stars, rating: votes > 0 ? Math.round(total / votes * 10) / 10 : 0, votes };
    } finally {
      this.rating.delete(pkey);
    }
  }

  async played(pkey: string | undefined, ids: string[], bot = false, alts: string[] = []): Promise<{ ok: boolean; counted: number; reason?: string }> {
    if (bot) return { ok: false, counted: 0, reason: 'bot' };
    if (!pkey || !PKEY_RE.test(pkey)) return { ok: false, counted: 0, reason: 'no_key' };
    if (this.now() - (this.lastPlayed.get(pkey) ?? -Infinity) < FORGE_RATE_GAP_MS) return { ok: false, counted: 0, reason: 'too_soon' };
    this.lastPlayed.set(pkey, this.now());
    await this.ensure();
    const keys = [pkey, ...alts];
    let counted = 0;
    for (const id of [...new Set(ids)].slice(0, FORGE_MAX_PLAYED)) {
      if (!ID_RE.test(id) || await this.store.played(id, keys)) continue;
      const e = await this.store.get(id);
      if (!e || e.hidden || ownsEntry(e, pkey, alts)) continue;
      await this.store.play(id, pkey, this.now());
      counted += 1;
    }
    return { ok: true, counted };
  }

  async get(pkey: string | undefined, id: string, alts: string[] = []): Promise<{ ok: true; id: string; mod: string; mine?: boolean } | { ok: false; reason: string }> {
    await this.ensure();
    const e = await this.store.get(id);
    const mine = e !== null && ownsEntry(e, pkey, alts);
    if (!e || (e.hidden && !mine)) return { ok: false, reason: 'gone' };
    if (!mine) {
      e.downloads += 1;
      await this.store.put(e);
      return { ok: true, id: e.id, mod: e.raw };
    }
    return { ok: true, id: e.id, mod: e.raw, mine: true };
  }

  async report(pkey: string | undefined, id: string, reason: string, alts: string[] = []): Promise<{ ok: boolean; reason?: string }> {
    if (!pkey || !PKEY_RE.test(pkey)) return { ok: false, reason: 'no_key' };
    await this.ensure();
    const e = await this.store.get(id);
    if (!e) return { ok: false, reason: 'gone' };
    if (ownsEntry(e, pkey, alts)) return { ok: false, reason: 'own' };
    if (e.reports.includes(pkey)) return { ok: true };
    e.reports.push(pkey);
    if (e.reports.length >= FORGE_HIDE_AT) e.hidden = true;
    await this.store.put(e);
    this.deps.log?.('WARN', 'FORGE', `report ${id} (${reason}) ${e.reports.length}${e.hidden ? ' hidden' : ''}`);
    return { ok: true };
  }

  async unpublish(pkey: string | undefined, id: string, alts: string[] = []): Promise<{ ok: boolean; reason?: string }> {
    if (!pkey || !PKEY_RE.test(pkey)) return { ok: false, reason: 'no_key' };
    await this.ensure();
    const e = await this.store.get(id);
    if (!e) return { ok: false, reason: 'gone' };
    if (!ownsEntry(e, pkey, alts)) return { ok: false, reason: 'not_yours' };
    await this.store.remove(id);
    return { ok: true };
  }
}

export let forgeBoard = new ForgeBoard(new MemoryForgeStore());
export function setForgeBoard(b: ForgeBoard): void { forgeBoard = b; }

export interface ForgeHandlerDeps<W> {
  keyOf: (ws: W, msg: Record<string, unknown>) => string | undefined;
  isBot: (ws: W) => boolean;
  send: (ws: W, data: object) => void;
}

export function forgeHandlers<W>(d: ForgeHandlerDeps<W>): Record<string, (ws: W, msg: Record<string, unknown>) => void> {
  return {
    forge_publish: (ws, msg) => {
      const k = d.keyOf(ws, msg);
      forgeBoard.publish(k, String(msg.mod), d.isBot(ws), altKeys(msg, k), msg.theme === true)
        .then(r => d.send(ws, { type: 'forge_published', ...r }))
        .catch(() => d.send(ws, { type: 'forge_published', ok: false, reason: 'unavailable' }));
    },
    forge_browse: (ws, msg) => {
      const page = typeof msg.page === 'number' ? msg.page : 1;
      const k = d.keyOf(ws, msg);
      forgeBoard.browse(k, page, typeof msg.q === 'string' ? msg.q : '', msg.mine === true, altKeys(msg, k), typeof msg.sort === 'string' ? msg.sort : 'new')
        .then(r => d.send(ws, { type: 'forge_list', ...r }))
        .catch(() => d.send(ws, { type: 'forge_list', mods: [], page: 1, pages: 1, total: 0, error: 'unavailable' }));
    },
    forge_get: (ws, msg) => {
      const id = String(msg.id);
      const k = d.keyOf(ws, msg);
      forgeBoard.get(k, id, altKeys(msg, k))
        .then(r => d.send(ws, { type: 'forge_mod', ...r, id }))
        .catch(() => d.send(ws, { type: 'forge_mod', ok: false, id, reason: 'unavailable' }));
    },
    forge_report: (ws, msg) => {
      const id = String(msg.id);
      const k = d.keyOf(ws, msg);
      forgeBoard.report(k, id, String(msg.reason), altKeys(msg, k))
        .then(r => d.send(ws, { type: 'forge_reported', id, ...r }))
        .catch(() => d.send(ws, { type: 'forge_reported', id, ok: false, reason: 'unavailable' }));
    },
    forge_rate: (ws, msg) => {
      const id = String(msg.id);
      const k = d.keyOf(ws, msg);
      forgeBoard.rate(k, id, Number(msg.stars), d.isBot(ws), altKeys(msg, k))
        .then(r => d.send(ws, { type: 'forge_rated', id, ...r }))
        .catch(() => d.send(ws, { type: 'forge_rated', id, ok: false, reason: 'unavailable' }));
    },
    forge_played: (ws, msg) => {
      const k = d.keyOf(ws, msg);
      const ids = Array.isArray(msg.ids) ? msg.ids.filter((i): i is string => typeof i === 'string') : [];
      forgeBoard.played(k, ids, d.isBot(ws), altKeys(msg, k))
        .then(r => d.send(ws, { type: 'forge_counted', ...r }))
        .catch(() => d.send(ws, { type: 'forge_counted', ok: false, counted: 0, reason: 'unavailable' }));
    },
    forge_unpublish: (ws, msg) => {
      const id = String(msg.id);
      const k = d.keyOf(ws, msg);
      forgeBoard.unpublish(k, id, altKeys(msg, k))
        .then(r => d.send(ws, { type: 'forge_unpublished', id, ...r }))
        .catch(() => d.send(ws, { type: 'forge_unpublished', id, ok: false, reason: 'unavailable' }));
    },
  };
}
