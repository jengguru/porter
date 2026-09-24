#!/usr/bin/env bash
# Builds Porter.app (Universal: arm64 + x86_64), ad-hoc signed with the hardened runtime.
#
#   scripts/build-app.sh                 # -> dist/Porter.app
#   ARCHS=arm64 scripts/build-app.sh     # single architecture (faster)
#   VERSION=0.2.0 scripts/build-app.sh   # set CFBundleShortVersionString
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHS="${ARCHS:-arm64 x86_64}"
OUT_DIR="${OUT_DIR:-dist}"
APP="$OUT_DIR/Porter.app"

arch_flags=()
for arch in $ARCHS; do arch_flags+=(--arch "$arch"); done

echo "==> Building ($ARCHS)"
swift build -c release --product Porter "${arch_flags[@]}"
BIN_DIR="$(swift build -c release --product Porter "${arch_flags[@]}" --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Porter" "$APP/Contents/MacOS/Porter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
for lproj in Resources/*.lproj; do
    cp -R "$lproj" "$APP/Contents/Resources/"
done
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing (ad-hoc, hardened runtime, no entitlements)"
codesign --force --sign - --options runtime --timestamp=none "$APP"
codesign --verify --strict --verbose=1 "$APP"

lipo -info "$APP/Contents/MacOS/Porter"
echo "==> Done: $APP"
