#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODE_DEV_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/FingerCount.app"

if [[ ! -d "$XCODE_DEV_DIR" ]]; then
  XCODE_DEV_DIR="$(xcode-select -p)"
fi
if [[ ! -d "$XCODE_DEV_DIR/Platforms/MacOSX.platform" ]]; then
  echo "未找到完整的 Xcode 开发环境：$XCODE_DEV_DIR" >&2
  exit 1
fi

SDK_PATH="$(DEVELOPER_DIR="$XCODE_DEV_DIR" xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

for ARCH in arm64 x86_64; do
  DEVELOPER_DIR="$XCODE_DEV_DIR" xcrun swiftc \
    -parse-as-library -O \
    -target "$ARCH-apple-macos13.0" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$BUILD_DIR/module-cache-$ARCH" \
    -o "$BUILD_DIR/FingerCount-$ARCH" \
    "$ROOT_DIR"/Sources/*.swift
done

DEVELOPER_DIR="$XCODE_DEV_DIR" xcrun lipo -create \
  "$BUILD_DIR/FingerCount-arm64" \
  "$BUILD_DIR/FingerCount-x86_64" \
  -output "$APP_DIR/Contents/MacOS/FingerCount"

if [[ -f "$ROOT_DIR/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
fi

chmod +x "$APP_DIR/Contents/MacOS/FingerCount"
plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
echo "已生成 $APP_DIR"
