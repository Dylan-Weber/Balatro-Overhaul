#!/usr/bin/env bash
# Runs java/test/.../HighRefreshRateTest against the HighRefreshRate smali of a freshly
# built runtime, with dalvikvm on an adb device or emulator (set ANDROID_SERIAL).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
sdk="${ANDROID_HOME:-$HOME/Android/Sdk}"
jar="$(ls "$sdk"/platforms/android-*/android.jar | sort -V | tail -1)"
d8="$(command -v d8 || ls "$sdk"/build-tools/*/d8 | sort -V | tail -1)"
work="$repo/.night/refresh_rate"
remote=/data/local/tmp/overhaul_refresh_rate

rm -rf "$work"
mkdir -p "$work/stub/org/love2d/android" "$work/classes" "$work/dex"
adb get-state >/dev/null

python3 "$here/make_apk.py" runtime --work "$work" --out "$work/runtime.apk" >/dev/null

# compile-only stub; the real class comes from the runtime's dex
cat > "$work/stub/org/love2d/android/HighRefreshRate.java" <<'EOF'
package org.love2d.android;
public class HighRefreshRate {
    public static android.view.Display.Mode pickMode(android.view.Display.Mode cur, android.view.Display.Mode[] modes) { return null; }
}
EOF
javac -nowarn --release 8 -d "$work/stub" -cp "$jar" "$work/stub/org/love2d/android/HighRefreshRate.java"
javac -nowarn --release 8 -d "$work/classes" -cp "$jar:$work/stub" "$here/java/test/org/love2d/android/HighRefreshRateTest.java"
"$d8" --min-api 21 --lib "$jar" --classpath "$work/stub" --output "$work/dex" $(find "$work/classes" -name '*.class')

adb shell rm -rf "$remote"
adb shell mkdir -p "$remote"
adb push -q "$work/runtime.apk" "$remote/runtime.apk"
adb push -q "$work/dex/classes.dex" "$remote/test.dex"
status=0
adb shell "dalvikvm -cp $remote/runtime.apk:$remote/test.dex org.love2d.android.HighRefreshRateTest; echo exit=\$?" | tee "$work/out.txt"
grep -q '^exit=0' "$work/out.txt" || status=1
adb shell rm -rf "$remote"
exit $status
