#!/bin/bash
# Full release pipeline for Blink
#
# Handles: version bump → build → DMG → appcast update → GitHub release
#
# Usage:
#   ./scripts/release.sh 1.9.0                    # Release with changelog prompt
#   ./scripts/release.sh 1.9.0 --notes "Fixed X"  # Release with inline notes
#   ./scripts/release.sh 1.9.0 --dry-run          # Build everything, skip publish
#
# Prerequisites: xcodegen, xcbeautify (optional), gh (GitHub CLI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APPCAST="$PROJECT_DIR/appcast.xml"
PROJECT_YML="$PROJECT_DIR/project.yml"
DMG_NAME="Blink.dmg"
REPO="rachitwatts/blink"
DRY_RUN=false
RELEASE_NOTES=""
SKIP_TESTS=false

# --- Argument parsing ---

usage() {
    echo "Usage: $0 <version> [--notes \"...\"] [--dry-run] [--skip-tests]"
    echo ""
    echo "  <version>      Semver version to release (e.g. 1.9.0)"
    echo "  --notes, -n    Release notes (HTML supported). Omit to use \$EDITOR."
    echo "  --dry-run      Build and prepare everything but don't push or publish"
    echo "  --skip-tests   Skip running tests before release"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

VERSION="$1"
shift

# Validate semver
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be semver (e.g. 1.9.0), got: $VERSION"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --notes|-n)
            RELEASE_NOTES="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# --- Helper functions ---

step() {
    echo ""
    echo "━━━ $1 ━━━"
}

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $1 is not installed"
        exit 1
    fi
}

# --- Preflight checks ---

step "Preflight checks"

check_tool xcodegen
check_tool xcodebuild
check_tool hdiutil
check_tool gh

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$DRY_RUN" = false ]; then
    echo "Warning: You're on branch '$CURRENT_BRANCH', not 'main'."
    read -rp "Continue anyway? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

if [ "$DRY_RUN" = false ] && ! git -C "$PROJECT_DIR" diff --quiet; then
    echo "Error: Working tree has uncommitted changes. Commit or stash first."
    exit 1
fi

# --- Get release notes ---

if [ -z "$RELEASE_NOTES" ]; then
    PREV_TAG=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")

    NOTES_FILE=$(mktemp)
    echo "<!-- Enter release notes below (HTML). Lines starting with <!-- are stripped. -->" > "$NOTES_FILE"
    echo "<ul>" >> "$NOTES_FILE"

    if [ -n "$PREV_TAG" ]; then
        echo "<!-- Commits since $PREV_TAG: -->" >> "$NOTES_FILE"
        git -C "$PROJECT_DIR" log "$PREV_TAG"..HEAD --pretty=format:"  <li>%s</li>" >> "$NOTES_FILE"
        echo "" >> "$NOTES_FILE"
    else
        echo "  <li>Initial release</li>" >> "$NOTES_FILE"
    fi

    echo "</ul>" >> "$NOTES_FILE"

    ${EDITOR:-vi} "$NOTES_FILE"

    RELEASE_NOTES=$(grep -v '^<!--' "$NOTES_FILE" || true)
    rm -f "$NOTES_FILE"

    if [ -z "$RELEASE_NOTES" ]; then
        echo "Error: Release notes are empty. Aborting."
        exit 1
    fi
fi

echo "Version:  $VERSION"
echo "Dry run:  $DRY_RUN"
echo "Notes:    $(echo "$RELEASE_NOTES" | head -1)..."

# --- Step 1: Bump version ---

step "1. Bumping version to $VERSION"

# Only bump the Blink target version (first occurrence), not BlinkWatch
awk -v ver="$VERSION" '!done && /MARKETING_VERSION:/ { sub(/MARKETING_VERSION: ".*"/, "MARKETING_VERSION: \"" ver "\""); done=1 } 1' "$PROJECT_YML" > "$PROJECT_YML.tmp"
mv "$PROJECT_YML.tmp" "$PROJECT_YML"
echo "Updated project.yml"

# --- Step 2: Generate Xcode project ---

step "2. Generating Xcode project"

cd "$PROJECT_DIR"
xcodegen generate

# --- Step 3: Run tests ---

if [ "$SKIP_TESTS" = false ]; then
    step "3. Running tests"

    xcodebuild -scheme Blink -destination 'platform=macOS' test 2>&1 \
        | if command -v xcbeautify &>/dev/null; then xcbeautify; else cat; fi

    echo "Tests passed"
else
    step "3. Skipping tests (--skip-tests)"
fi

# --- Step 4: Build release ---

step "4. Building release"

xcodebuild -project Blink.xcodeproj \
    -scheme Blink \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build 2>&1 \
    | if command -v xcbeautify &>/dev/null; then xcbeautify; else cat; fi

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/Blink.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed - Blink.app not found at $APP_PATH"
    exit 1
fi

echo "Build succeeded"

# --- Step 5: Create DMG ---

step "5. Creating DMG"

rm -f "$BUILD_DIR/$DMG_NAME" "$BUILD_DIR/Blink-rw.dmg"

hdiutil create \
    -size 100m \
    -fs HFS+ \
    -volname "Blink" \
    "$BUILD_DIR/Blink-rw.dmg"

MOUNT_DIR=$(hdiutil attach "$BUILD_DIR/Blink-rw.dmg" -nobrowse | grep '/Volumes/' | sed 's/.*\(\/Volumes\/.*\)/\1/')
cp -R "$APP_PATH" "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR"

hdiutil convert "$BUILD_DIR/Blink-rw.dmg" \
    -format UDZO \
    -o "$BUILD_DIR/$DMG_NAME"

rm -f "$BUILD_DIR/Blink-rw.dmg"

DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_SIZE=$(stat -f%z "$DMG_PATH")

echo "DMG created: $DMG_PATH ($DMG_SIZE bytes)"

# --- Step 6: Update appcast.xml ---

step "6. Updating appcast.xml"

PUB_DATE=$(date -R)
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/$DMG_NAME"

# Insert new <item> before </channel> using Python (handles multiline XML safely)
python3 -c "
import sys
appcast = open(sys.argv[1]).read()
item = '''    <item>
      <title>Version $VERSION</title>
      <description><![CDATA[$RELEASE_NOTES]]></description>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure
        url=\"$DOWNLOAD_URL\"
        sparkle:version=\"$VERSION\"
        sparkle:shortVersionString=\"$VERSION\"
        type=\"application/octet-stream\"
        length=\"$DMG_SIZE\"
        />
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>
'''
appcast = appcast.replace('  </channel>', item + '  </channel>')
open(sys.argv[1], 'w').write(appcast)
" "$APPCAST"

echo "Appcast updated with v$VERSION entry"

# --- Step 7: Publish ---

if [ "$DRY_RUN" = true ]; then
    step "7. Dry run - skipping publish"
    echo "Would commit version bump + appcast"
    echo "Would create GitHub release v$VERSION with $DMG_PATH"
    echo ""
    echo "To publish for real, run without --dry-run"
    echo "Note: project.yml and appcast.xml have been modified locally"
    exit 0
fi

step "7. Publishing"

# Commit version bump + appcast update
git -C "$PROJECT_DIR" add "$PROJECT_YML" "$APPCAST"
git -C "$PROJECT_DIR" commit -m "Release v$VERSION"

# Push
git -C "$PROJECT_DIR" push origin "$CURRENT_BRANCH"

# Create GitHub release
if gh release view "v$VERSION" --repo "$REPO" &>/dev/null; then
    echo "Release v$VERSION exists, uploading DMG..."
    gh release upload "v$VERSION" "$DMG_PATH" --repo "$REPO" --clobber
else
    # Convert HTML notes to markdown-ish for GitHub release body
    gh release create "v$VERSION" "$DMG_PATH" \
        --repo "$REPO" \
        --title "Blink v$VERSION" \
        --notes "$(cat <<EOF
## Blink v$VERSION

$RELEASE_NOTES

### Installation
1. Download \`Blink.dmg\`
2. Open the DMG and drag Blink to Applications
3. First launch: Right-click → Open → Click "Open"

### Auto-Update
If you already have Blink installed, the app will offer this update automatically.

### Requirements
- macOS 14.0 or later
EOF
)"
fi

echo ""
echo "━━━ Release complete ━━━"
echo ""
echo "  Version:  $VERSION"
echo "  Release:  https://github.com/$REPO/releases/tag/v$VERSION"
echo "  Appcast:  https://raw.githubusercontent.com/$REPO/main/appcast.xml"
echo ""
