#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build"
xcodebuild -version
xcodebuild -project "$root/work/love/platform/xcode/love.xcodeproj" \
  -target love-ios -configuration Release -sdk iphoneos \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  GCC_GENERATE_DEBUGGING_SYMBOLS=NO DEBUG_INFORMATION_FORMAT=dwarf \
  SYMROOT="$root/work/xcbuild" OBJROOT="$root/work/xcbuild" build
app="$root/work/xcbuild/Release-iphoneos/love.app"
if strings "$app/love" | grep -qi mpg123 || nm "$app/love" 2>/dev/null | grep -qi mpg123; then
  echo "error: libmpg123 found in the binary; update THIRD_PARTY_IOS.md (LGPL position)"; exit 1
fi
echo "app: $app"
