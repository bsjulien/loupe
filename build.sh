#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Loupe"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SDK=$(xcrun --sdk macosx --show-sdk-path)
ARCH="${1:-arm64}"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Compiling ($ARCH)..."
swiftc $(find "$PROJECT_DIR/Loupe" -name "*.swift") \
  -sdk "$SDK" \
  -target "$ARCH-apple-macos14.0" \
  -O \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
  -framework AppKit -framework SwiftUI -framework ScreenCaptureKit \
  -framework Vision -framework Carbon -framework CoreImage -framework ServiceManagement

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.julienbarezi.loupe</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Loupe</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Personal use</string>
</dict>
</plist>
PLIST

SIGNING_IDENTITY="Loupe Local Dev"
if ! security find-certificate -c "$SIGNING_IDENTITY" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
  echo "Warning: '$SIGNING_IDENTITY' identity not found, falling back to ad-hoc signing (permission grants won't survive rebuilds)."
  SIGNING_IDENTITY="-"
fi
echo "Code signing (identity: $SIGNING_IDENTITY)..."
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
