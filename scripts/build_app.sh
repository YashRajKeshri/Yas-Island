#!/usr/bin/env bash
set -e

APP_NAME="Yas Island"
BUNDLE_ID="com.yasisland.app"
VERSION="1.0.0"
BUILD_DIR="$(pwd)/.build/arm64-apple-macosx/release"
OUTPUT_APP="$(pwd)/${APP_NAME}.app"
DIST_DIR="$(pwd)/dist"

echo "🔨 [1/4] Compiling optimized release binary..."
swift build -c release

echo "📦 [2/4] Assembling macOS App Bundle (${APP_NAME}.app)..."
rm -rf "${OUTPUT_APP}"
mkdir -p "${OUTPUT_APP}/Contents/MacOS"
mkdir -p "${OUTPUT_APP}/Contents/Resources"

# Copy Binary
cp "${BUILD_DIR}/YasIsland" "${OUTPUT_APP}/Contents/MacOS/YasIsland"
chmod +x "${OUTPUT_APP}/Contents/MacOS/YasIsland"

# Generate Info.plist
cat <<EOF > "${OUTPUT_APP}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>YasIsland</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Yas Island needs access to Media and Browsers to display Now Playing metadata.</string>
</dict>
</plist>
EOF

# Ad-hoc code signing for local execution
echo "✍️ [3/4] Signing application bundle..."
codesign --force --deep --sign - "${OUTPUT_APP}"

echo "🎁 [4/4] Creating distribution ZIP..."
mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${APP_NAME}-v${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent "${OUTPUT_APP}" "${DIST_DIR}/${APP_NAME}-v${VERSION}.zip"

echo ""
echo "✅ BUILD & PACKAGING COMPLETE!"
echo "📍 Application Bundle: ${OUTPUT_APP}"
echo "📍 Shareable ZIP File: ${DIST_DIR}/${APP_NAME}-v${VERSION}.zip"
echo ""
echo "To install on your Mac: cp -R \"${OUTPUT_APP}\" /Applications/"
