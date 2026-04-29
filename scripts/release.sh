#!/bin/bash
# Full release pipeline for Blink
#
# Handles: version bump → build → DMG → sign → upload to R2 → GitHub release
#
# Usage:
#   ./scripts/release.sh 1.9.0                    # Release with changelog prompt
#   ./scripts/release.sh 1.9.0 --notes "Fixed X"  # Release with inline notes
#   ./scripts/release.sh 1.9.0 --dry-run          # Build everything, skip publish
#
# Prerequisites: xcodegen, xcbeautify (optional), gh (GitHub CLI), aws CLI
# Credentials:   .env file with R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_URL

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

# Load R2 credentials from .env
ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Error: .env file not found at $ENV_FILE"
    echo "Create it with: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_URL"
    exit 1
fi

R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

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
            if [ -z "${2:-}" ]; then
                echo "Error: --notes requires a value"
                usage
            fi
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
check_tool aws

# Find Sparkle's sign_update binary from the SPM artifacts
SIGN_UPDATE=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "sign_update" -path "*/artifacts/sparkle/*" -type f 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
    echo "Error: Sparkle sign_update not found. Build the project once in Xcode to fetch Sparkle."
    exit 1
fi
echo "Using sign_update: $SIGN_UPDATE"

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

# Auto-increment CURRENT_PROJECT_VERSION (build number) for Sparkle version comparison
CURRENT_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION' "$PROJECT_YML" | sed 's/.*"\(.*\)"/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
awk -v build="$NEW_BUILD" '!done && /CURRENT_PROJECT_VERSION:/ { sub(/CURRENT_PROJECT_VERSION: ".*"/, "CURRENT_PROJECT_VERSION: \"" build "\""); done=1 } 1' "$PROJECT_YML" > "$PROJECT_YML.tmp"
mv "$PROJECT_YML.tmp" "$PROJECT_YML"

echo "Updated project.yml (version: $VERSION, build: $NEW_BUILD)"

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

# --- Step 6: Sign DMG with EdDSA ---

step "6. Signing DMG with EdDSA"

SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH")
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')

if [ -z "$ED_SIGNATURE" ]; then
    echo "Error: Failed to generate EdDSA signature."
    echo "sign_update output: $SIGN_OUTPUT"
    echo ""
    echo "If this is your first release, generate a keypair first:"
    echo "  $SIGN_UPDATE --generate"
    echo "Then add the public key to Blink/Info.plist as SUPublicEDKey."
    exit 1
fi

echo "EdDSA signature: ${ED_SIGNATURE:0:20}..."

# --- Step 7: Update appcast.xml ---

step "7. Updating appcast.xml"

PUB_DATE=$(date -R)
DOWNLOAD_URL="${R2_PUBLIC_URL}/Blink-v${VERSION}.dmg"

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
        sparkle:edSignature=\"$ED_SIGNATURE\"
        sparkle:version=\"$NEW_BUILD\"
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

# --- Step 8: Publish ---

if [ "$DRY_RUN" = true ]; then
    step "8. Dry run - skipping publish"
    echo "Would commit version bump + appcast"
    echo "Would create GitHub release v$VERSION with $DMG_PATH"
    echo ""
    echo "To publish for real, run without --dry-run"
    echo "Note: project.yml and appcast.xml have been modified locally"
    exit 0
fi

step "8. Uploading to Cloudflare R2"

# Upload DMG with versioned filename
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET/Blink-v${VERSION}.dmg" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type "application/octet-stream"

echo "DMG uploaded: ${R2_PUBLIC_URL}/Blink-v${VERSION}.dmg"

# Upload appcast.xml
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    aws s3 cp "$APPCAST" "s3://$R2_BUCKET/appcast.xml" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type "application/xml"

echo "Appcast uploaded: ${R2_PUBLIC_URL}/appcast.xml"

# --- Step 9: Commit and publish ---

step "9. Publishing"

# Commit version bump + regenerated Xcode project + appcast update
git -C "$PROJECT_DIR" add "$PROJECT_YML" "$APPCAST" "$PROJECT_DIR/Blink.xcodeproj/project.pbxproj"
git -C "$PROJECT_DIR" commit -m "Release v$VERSION"

# Push
git -C "$PROJECT_DIR" push origin "$CURRENT_BRANCH"

# Create GitHub release (without DMG — it's on R2 now)
if ! gh release view "v$VERSION" --repo "$REPO" &>/dev/null; then
    gh release create "v$VERSION" \
        --repo "$REPO" \
        --title "Blink v$VERSION" \
        --notes "$(cat <<EOF
## Blink v$VERSION

$RELEASE_NOTES

### Download
[Blink.dmg](${R2_PUBLIC_URL}/Blink-v${VERSION}.dmg)

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
echo "  DMG:      ${R2_PUBLIC_URL}/Blink-v${VERSION}.dmg"
echo "  Appcast:  ${R2_PUBLIC_URL}/appcast.xml"
echo "  Release:  https://github.com/$REPO/releases/tag/v$VERSION"
echo ""
