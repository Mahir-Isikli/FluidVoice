#!/bin/bash
# Rebuild the custom FluidVoice (OSS path), embed the framework the OSS build
# omits, ad-hoc sign, and install it as the canonical /Applications/FluidVoice.app
# (so Raycast / Spotlight / login all launch the build with our changes).
#
# Usage:
#   ./rebuild.sh           # build + embed + sign + install to /Applications
#   ./rebuild.sh --open    # ...then launch it
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="/Applications/FluidVoice.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "==> Building (OSS xcodebuild path, no codesign)…"
xcodebuild build \
  -project "$DIR/Fluid.xcodeproj" \
  -scheme Fluid \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  >/tmp/fluidvoice-build.log 2>&1 || { echo "BUILD FAILED — see /tmp/fluidvoice-build.log"; tail -20 /tmp/fluidvoice-build.log; exit 1; }

REL="$(xcodebuild -project "$DIR/Fluid.xcodeproj" -scheme Fluid -destination 'platform=macOS,arch=arm64' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{print $2; exit}')"
APP="$REL/FluidVoice.app"
echo "==> Built: $APP"

echo "==> Embedding MediaRemoteAdapter.framework (OSS build does not bundle it)…"
mkdir -p "$APP/Contents/Frameworks"
cp -R "$REL/PackageFrameworks/MediaRemoteAdapter.framework" "$APP/Contents/Frameworks/"

echo "==> Installing to $DEST…"
osascript -e 'quit app "FluidVoice"' 2>/dev/null || true
pkill -f "FluidVoice.app/Contents/MacOS/FluidVoice" 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Ad-hoc signing…"
codesign --force --sign - --timestamp=none "$DEST/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign --force --deep --sign - --entitlements "$DIR/Fluid.entitlements" --timestamp=none "$DEST"
codesign --verify --deep "$DEST" && echo "    signature OK"
"$LSREGISTER" -f "$DEST" || true

echo "==> Installed: $DEST"
if [ "${1:-}" = "--open" ]; then
  echo "==> Launching…"
  open "$DEST"
fi
