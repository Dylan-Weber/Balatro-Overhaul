export const RUN_MODS_MAX_IDS = 200;
export const RUN_MODS_MAX_LEN = 64;
const ID_RE = /^[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+$/;

function cleanIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out = new Set<string>();
  for (const x of raw) {
    if (out.size >= RUN_MODS_MAX_IDS) break;
    if (typeof x === 'string' && x.length <= RUN_MODS_MAX_LEN && ID_RE.test(x)) out.add(x);
  }
  return [...out].sort();
}

export function cleanRunMods(raw: unknown): { decks: string[]; off: string[] } | undefined {
  if (Array.isArray(raw) && raw.length === 0) return { decks: [], off: [] };
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
  const r = raw as Record<string, unknown>;
  return { decks: cleanIds(r.decks), off: cleanIds(r.off) };
}

export function runModsOn(settings: Record<string, unknown> | undefined): boolean {
  const r = cleanRunMods(settings?.run_mods);
  return !!r && (r.decks.length > 0 || r.off.length > 0);
}
