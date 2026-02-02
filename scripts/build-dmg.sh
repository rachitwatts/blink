#!/bin/bash
# Build Blink.dmg for distribution
# Usage: ./scripts/build-dmg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_NAME="Blink.dmg"

echo "Building Blink..."

# Generate Xcode project
cd "$PROJECT_DIR"
xcodegen generate

# Build Release
xcodebuild -project Blink.xcodeproj \
    -scheme Blink \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/Blink.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed - Blink.app not found"
    exit 1
fi

echo "Creating DMG..."

# Create staging directory
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy app and create Applications symlink
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -sf /Applications "$STAGING_DIR/Applications"

# Remove old DMG if exists
rm -f "$BUILD_DIR/$DMG_NAME"

# Create DMG
hdiutil create \
    -volname "Blink" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

# Clean up
rm -rf "$STAGING_DIR"

echo ""
echo "✓ DMG created: $BUILD_DIR/$DMG_NAME"
echo ""
echo "To install:"
echo "  1. Open the DMG"
echo "  2. Drag Blink to Applications"
echo "  3. Right-click → Open (first launch only)"
