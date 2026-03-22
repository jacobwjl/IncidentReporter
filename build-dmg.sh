#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="IncidentReporter"

echo "==> Building $APP_NAME (Release)..."
cd "$PROJECT_DIR"
xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    2>&1 | tail -5

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed — .app not found"
    exit 1
fi

echo "==> App built at: $APP_PATH"

# Create a staging folder for the DMG contents
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

# Add a symlink to /Applications for drag-to-install
ln -s /Applications "$STAGING/Applications"

# Remove old DMG if it exists
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"

echo "==> Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo ""
echo "To install: Open the DMG, drag IncidentReporter to Applications."
echo "To update:  Replace the old .app in /Applications with the new one."
echo "            Your data is stored separately in ~/Library/Application Support/IncidentReporter/"
echo "            so it survives app updates."
