#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
cd "$REPO"
RC=0
luajit "$HERE/file_keys.lua" assets/localization assets/overhaul/localization | grep -E "^==|^MISSING" || true
luajit "$HERE/file_keys.lua" assets/localization assets/overhaul/localization > /dev/null || RC=1
SL="$(mktemp -d)"
mkdir -p "$SL/empty"
DRY_RUN_OUT="$SL/out" luajit tools/mods/dry_run.lua "$REPO" "$SL/empty" "$REPO/assets" "$REPO/assets/smods" > /dev/null 2>&1
mkdir -p "$SL/loc" && cp assets/smods/localization/*.lua "$SL/loc/" && cp "$SL"/out/smods/localization/*.lua "$SL/loc/" 2>/dev/null
luajit "$HERE/file_keys.lua" "$SL/loc" | sed "s|$SL/loc|assets/smods/localization (patched)|" | grep -E "^==|^MISSING" || true
luajit "$HERE/file_keys.lua" "$SL/loc" > /dev/null || RC=1
rm -rf "$SL"
luajit "$HERE/launcher_keys.lua" tools/release/launcher/lang.lua || RC=1
if [ "${AUDIT:-0}" = 1 ]; then
  export MENU_OUT="${MENU_OUT:-$REPO/.night/lang/shots}"
  bash tools/menu_shots/run.sh lang_audit plain "wait:2|lua:assert(loadfile('$HERE/loc_audit.lua'))()|quit" > /dev/null 2>&1
  A="$MENU_OUT/lang_audit/loc_audit.txt"
  tail -1 "$A"
  BAD=$(grep -cE "^(TREE_MISSING|MT_ONLY_FR|MT_ONLY_ES)" "$A")
  FMT=$(grep -E "^MT_FMT" "$A" | grep -vc "	mp_sd_round	")
  echo "== game tables: missing $BAD, broken placeholders $FMT"
  grep -E "^(TREE_MISSING|MT_ONLY_FR|MT_ONLY_ES|MT_FMT)" "$A" | grep -v "	mp_sd_round	" | head -20
  [ "$BAD" = 0 ] && [ "$FMT" = 0 ] || RC=1
fi
echo "lang test rc $RC"
exit $RC
