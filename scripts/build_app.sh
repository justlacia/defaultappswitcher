#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="DefaultAppSwitcher"
EXEC_NAME="DefaultAppSwitcher"
BUNDLE_ID="com.justlacia.defaultappswitcher"
VERSION="${1:-1.0.0}"
BUILD_NUMBER="1"

BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

TMP_BIN_DIR="$(mktemp -d)"
DMG_STAGING="$(mktemp -d)"
trap 'rm -rf "$TMP_BIN_DIR" "$DMG_STAGING"' EXIT

echo "1/6 Building Universal release binaries (arm64 + x86_64)..."
swift build -c release --triple arm64-apple-macosx14.0
ARM64_BIN="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/$EXEC_NAME"
if [[ ! -f "$ARM64_BIN" ]]; then
  echo "Error: arm64 binary not found at $ARM64_BIN" >&2
  exit 1
fi
cp "$ARM64_BIN" "$TMP_BIN_DIR/${EXEC_NAME}-arm64"

swift build -c release --triple x86_64-apple-macosx14.0
X86_BIN="$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)/$EXEC_NAME"
if [[ ! -f "$X86_BIN" ]]; then
  echo "Error: x86_64 binary not found at $X86_BIN" >&2
  exit 1
fi
cp "$X86_BIN" "$TMP_BIN_DIR/${EXEC_NAME}-x86_64"

echo "2/6 Assembling .app bundle and creating Universal binary with lipo..."
rm -rf "$APP_BUNDLE" "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DIST_DIR"

lipo -create "$TMP_BIN_DIR/${EXEC_NAME}-arm64" "$TMP_BIN_DIR/${EXEC_NAME}-x86_64" -output "$MACOS_DIR/$EXEC_NAME"
chmod +x "$MACOS_DIR/$EXEC_NAME"
lipo -info "$MACOS_DIR/$EXEC_NAME"

echo "3/6 Generating AppIcon.icns and Info.plist..."
swift "$ROOT_DIR/scripts/generate_icon.swift" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXEC_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "4/6 Signing and verifying app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "5/6 Creating downloadable .zip and .dmg archives..."
ZIP_NAME="${APP_NAME}-v${VERSION}-macOS-Universal.zip"
DMG_NAME="${APP_NAME}-v${VERSION}-macOS-Universal.dmg"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIST_DIR/$ZIP_NAME"

cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$DMG_NAME"

echo "6/6 Generating SHA256 checksums..."
(cd "$DIST_DIR" && shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > SHA256SUMS.txt)

ls -lh "$DIST_DIR"
cat "$DIST_DIR/SHA256SUMS.txt"
echo "Done: $APP_BUNDLE"
