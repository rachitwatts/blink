#!/bin/bash
# Build Blink.dmg and optionally create a GitHub release
#
# Usage:
#   ./scripts/build-dmg.sh              # Build DMG only
#   ./scripts/build-dmg.sh --release    # Build DMG and create GitHub release

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_NAME="Blink.dmg"
CREATE_RELEASE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release|-r)
            CREATE_RELEASE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--release]"
            exit 1
            ;;
    esac
done

# Get version from project.yml
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
fi

echo "Building Blink v$VERSION..."

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

# Create GitHub release if requested
if [ "$CREATE_RELEASE" = true ]; then
    echo ""
    echo "Creating GitHub release v$VERSION..."

    # Check if release already exists
    if gh release view "v$VERSION" &>/dev/null; then
        echo "Release v$VERSION already exists. Updating..."
        gh release upload "v$VERSION" "$BUILD_DIR/$DMG_NAME" --clobber
    else
        # Create new release
        gh release create "v$VERSION" "$BUILD_DIR/$DMG_NAME" \
            --title "Blink v$VERSION" \
            --notes "## Blink v$VERSION

### Installation
1. Download \`Blink.dmg\`
2. Open the DMG and drag Blink to Applications
3. First launch: Right-click → Open → Click \"Open\"

### Requirements
- macOS 14.0 or later"
    fi

    echo ""
    echo "✓ Release created: https://github.com/rachitwatts/blink/releases/tag/v$VERSION"
fi

echo ""
echo "Done!"
