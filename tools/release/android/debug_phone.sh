#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--save] [--no-install]"
    echo "Builds Balatro Debug for the phone (own app, own saves), installs it with adb"
    echo "and forwards the local debug server (127.0.0.1:3460) over USB."
    echo "  --save        replace the phone Debug save with the PC Debug save"
    echo "  --no-install  only build the APK"
}

copy_save=0
install=1
for a in "$@"; do
    case "$a" in
        --save) copy_save=1 ;;
        --no-install) install=0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
pkg="com.jupiteriansoul.balatrooverhaul.debug"
identity="OverhaulDebug"
pc_save="${XDG_DATA_HOME:-$HOME/.local/share}/love/$identity"
key_dir="${XDG_DATA_HOME:-$HOME/.local/share}/balatro-debug-android/keys"
work="$repo/.night/debug_phone"
stage="$work/game"

rm -rf "$stage" "$work/apk"
mkdir -p "$stage" "$work/apk" "$key_dir"

echo "=== 1/4 game files ==="
rsync -a \
    --exclude dexopt \
    --exclude DEV_CHANGELOG.txt --exclude ERROR_LOG.txt --exclude SESSION_LOG.txt \
    --exclude FEATURES.txt --exclude info.txt \
    "$repo/assets/" "$stage/"
sed -i "s/t.title = 'Balatro'/t.title = 'Balatro Debug'/" "$stage/balatro/conf.lua"
sed -i "s/^\tt.title = 'Balatro Debug'/&\n\tt.identity = '$identity'/" "$stage/balatro/conf.lua"
grep -q "t.identity = '$identity'" "$stage/balatro/conf.lua" || { echo "conf.lua layout changed, identity not set"; exit 1; }
sed -i 's|^mp_config.SERVER_URL *=.*|mp_config.SERVER_URL          = "ws://127.0.0.1:3460/ws"|' "$stage/multiplayer/mp_config.lua"
cp "$repo/linux/debug_peer.lua" "$stage/debug_peer.lua"
printf '\nrequire "debug_peer"\n' >> "$stage/main.lua"

echo "=== 2/4 runtime ==="
python3 "$here/make_apk.py" runtime --package "$pkg" --label "Balatro Debug" --debuggable --out "$work/runtime.apk"

echo "=== 3/4 app ==="
python3 "$here/make_apk.py" build --game "$stage" --runtime "$work/runtime.apk" --out "$work/apk" --key-dir "$key_dir"
apk="$(ls -t "$work/apk/"*.apk | head -1)"
echo "APK: $apk"
(( install )) || exit 0

echo "=== 4/4 phone ==="
adb get-state >/dev/null
adb shell am force-stop "$pkg" 2>/dev/null || true
if ! adb install -r "$apk"; then
    adb push "$apk" /data/local/tmp/balatro_debug.apk
    adb shell pm install -r /data/local/tmp/balatro_debug.apk
    adb shell rm -f /data/local/tmp/balatro_debug.apk
fi
adb reverse tcp:3460 tcp:3460

if (( copy_save )); then
    [[ -d "$pc_save" ]] || { echo "No PC Debug save at $pc_save"; exit 1; }
    tarball="$work/save.tar"
    tar -C "$pc_save" -cf "$tarball" .
    adb push "$tarball" /data/local/tmp/balatro_debug_save.tar
    adb shell run-as "$pkg" sh -c "'rm -rf files/save/$identity && mkdir -p files/save/$identity && tar -xf /data/local/tmp/balatro_debug_save.tar -C files/save/$identity'"
    adb shell rm -f /data/local/tmp/balatro_debug_save.tar
    rm -f "$tarball"
    echo "PC Debug save copied to the phone"
fi
echo "Balatro Debug installed ($pkg)"
