#!/usr/bin/env bash
set -euo pipefail
ios="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pick="${1:?usage: boot_test.sh Balatro.exe plain|modded [mod folder ...]}"
mode="${2:?usage: boot_test.sh Balatro.exe plain|modded [mod folder ...]}"
shift 2
work="$ios/build/work"
t="$work/boot-$mode"
love="${LOVE:-$(command -v love)}"
rm -rf "$t"; mkdir -p "$t/out"
cp -R "$work/launcher" "$t/app"
mv "$t/app/main.lua" "$t/app/main_real.lua"
cp "$ios/tests/boot/main.lua" "$ios/tests/boot/conf.lua" "$t/app/"
export XDG_DATA_HOME="$t/data"
save="$XDG_DATA_HOME/love/BalatroOverhaulIOSBoot"
mkdir -p "$save"
if [ "$mode" = modded ]; then
  mkdir -p "$save/mods"
  : > "$save/mods/enabled.txt"
  printf 'modded\n' > "$save/mods/session.txt"
  for m in "$@"; do
    cp -RL "$m" "$save/mods/"
    basename "$m" >> "$save/mods/enabled.txt"
  done
fi
IOS_BOOT_OUT="$t/out" IOS_BOOT_PICK="$pick" IOS_BOOT_AS_IOS="${IOS_BOOT_AS_IOS:-1}" \
  timeout "${IOS_BOOT_TIMEOUT:-900}" "$love" "$t/app" > "$t/out/love.txt" 2>&1 || echo "love exited with $?"
cat "$t/out/boot.log"
for f in ios_boot_wait.png ios_boot_menu.png ios_boot_main.png ios_boot_settings.png ios_boot_credits.png; do [ -f "$save/$f" ] && cp "$save/$f" "$t/out/"; done
modded_ok=1
if [ "$mode" = modded ] && ! grep -Eq '^menu .* smods true mods_loaded [1-9]' "$t/out/boot.log"; then modded_ok=0; echo "mods did not load"; fi
[ "$modded_ok" = 1 ] && grep -q '^menu ' "$t/out/boot.log" && grep -q '^import true' "$t/out/boot.log" && grep -q '^picked_copy_left false official_copy_left false' "$t/out/boot.log" \
  && ! grep -q 'ios_frames 0 ' "$t/out/boot.log" && echo "BOOT $mode PASS" || { echo "BOOT $mode FAIL"; tail -20 "$t/out/love.txt"; exit 1; }
