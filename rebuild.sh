#!/bin/bash
# Rebuild the custom FluidVoice (OSS path), embed the framework the OSS build
# omits, ad-hoc sign, and stage a stable standalone copy under ./dist.
#
# Usage:
#   ./rebuild.sh           # build + embed + sign + stage to ./dist
#   ./rebuild.sh --open    # ...then relaunch the staged app
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

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

echo "==> Ad-hoc signing…"
codesign --force --sign - --timestamp=none "$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign --force --deep --sign - --entitlements "$DIR/Fluid.entitlements" --timestamp=none "$APP"
codesign --verify --deep "$APP" && echo "    signature OK"

echo "==> Staging stable copy to ./dist/FluidVoice.app…"
mkdir -p "$DIR/dist"
rm -rf "$DIR/dist/FluidVoice.app"
cp -R "$APP" "$DIR/dist/FluidVoice.app"

echo "==> Done: $DIR/dist/FluidVoice.app"

if [ "${1:-}" = "--open" ]; then
  echo "==> Relaunching…"
  osascript -e 'quit app "FluidVoice"' 2>/dev/null || true
  pkill -f "FluidVoice.app/Contents/MacOS/FluidVoice" 2>/dev/null || true
  sleep 1
  open "$DIR/dist/FluidVoice.app"
fi
