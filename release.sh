#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="IncidentReporter"
SPARKLE_BIN="$(find ~/Library/Developer/Xcode/DerivedData -path "*/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)"

if [ -z "$SPARKLE_BIN" ]; then
    echo "❌ Sparkle tools not found. Build the project in Xcode first to download the package."
    exit 1
fi

# Get version from project.yml
VERSION=$(grep "MARKETING_VERSION:" "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
if [ -z "$VERSION" ]; then
    echo "❌ Could not read version from project.yml"
    exit 1
fi

echo "==> Building $APP_NAME v$VERSION (Release)..."

# Regenerate project to pick up any config changes
cd "$PROJECT_DIR"
xcodegen generate 2>&1 | tail -2

xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    2>&1 | tail -3

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed — .app not found"
    exit 1
fi

echo "==> App built at: $APP_PATH"

# Create DMG
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_PATH"

echo "==> Creating DMG..."
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    2>&1 | tail -2

rm -rf "$STAGING"

echo "==> Signing DMG with Sparkle EdDSA..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1)
echo "   Signature: $SIGNATURE"

# Extract the edSignature and length values
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//' | sed 's/"//')
FILE_LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | sed 's/length="//' | sed 's/"//')

echo "==> Generating appcast.xml..."
DOWNLOAD_URL="https://github.com/jacobwjl/IncidentReporter/releases/download/v${VERSION}/${APP_NAME}-${VERSION}.dmg"
PUB_DATE=$(date -R)

cat > "$PROJECT_DIR/appcast.xml" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>$APP_NAME Changelog</title>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        type="application/octet-stream"
        sparkle:edSignature="$ED_SIGNATURE"
        length="$FILE_LENGTH"
      />
    </item>
  </channel>
</rss>
APPCAST_EOF

echo "==> Publishing to GitHub..."

# Commit the updated appcast
cd "$PROJECT_DIR"
git add appcast.xml project.yml
git commit -m "Release v${VERSION}" --allow-empty 2>/dev/null || true
git push origin main

# Create GitHub release with the DMG
gh release create "v${VERSION}" \
    "$DMG_PATH" \
    --title "IncidentReporter v${VERSION}" \
    --notes "## IncidentReporter v${VERSION}

Download the DMG, open it, and drag IncidentReporter to your Applications folder.

**First launch:** Right-click the app → Open (required once since it's not signed with an Apple Developer certificate).

**Updating:** The app checks for updates automatically via Sparkle. You can also check manually via IncidentReporter → Check for Updates." \
    --latest

echo ""
echo "✅ Released v${VERSION}!"
echo "   GitHub: https://github.com/jacobwjl/IncidentReporter/releases/tag/v${VERSION}"
echo "   DMG:    $DMG_PATH"
echo "   Appcast committed and pushed to main."
