# Blink - Project Instructions

## CI / GitHub Actions

When modifying `.github/workflows/ci.yml`, always include `brew link` after `brew install`:

```yaml
- name: Install dependencies
  run: |
    brew install xcodegen xcbeautify
    brew link xcodegen xcbeautify 2>/dev/null || true
```

**Why:** The CI caches Homebrew cellar files (`/opt/homebrew/Cellar/`), but cache restore does not recreate symlinks in `/opt/homebrew/bin/`. Without `brew link`, tools are "installed but not linked" and not on PATH.

## Build & Test

```bash
# Build
xcodebuild -scheme Blink -destination 'platform=macOS' build

# Run tests (87 unit tests)
xcodebuild -scheme Blink -destination 'platform=macOS' test
```

## Releasing

When the user asks to release, you MUST build the DMG and attach it to the GitHub release. Every release needs a `Blink.dmg` asset.

### Steps

1. Bump `MARKETING_VERSION` in `project.yml`
2. Run `xcodegen generate` to regenerate the Xcode project
3. Build the DMG: `bash scripts/build-dmg.sh`
4. If the build script fails due to provisioning/signing, build manually:
   ```bash
   xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Release \
     -derivedDataPath build/DerivedData \
     CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
     PROVISIONING_PROFILE_SPECIFIER="" build
   ```
   Then create the DMG with `hdiutil` (see script for steps).
5. Create the GitHub release with the DMG attached:
   ```bash
   gh release create v{VERSION} build/Blink.dmg --title "Blink v{VERSION}" --notes "..."
   ```
   Or upload to an existing release:
   ```bash
   gh release upload v{VERSION} build/Blink.dmg --clobber
   ```

**Never create a release without the DMG.** Users download the app from the release assets.

## Codex Code Review (`/codex-review`)

After raising a PR, run `/codex-review` for a multi-pass review loop:
- Codex reviews → Claude fixes → Codex re-reviews → repeat
- Exits on: Codex approval, Claude rejecting non-actionable feedback, or 10 passes

### Codex CLI invocation

**Always use the `codex review` subcommand:**

```bash
codex review --base main --model gpt-5.3-codex-high
```

**Do NOT use `codex --full-auto` or `codex --interactive`.** These require an interactive TTY and fail when run from a tool subprocess (error: `stdin is not a terminal`). The `codex review` subcommand is the non-interactive alternative designed for this use case.

- `--base main`: Diffs against the base branch
- `--model gpt-5.3-codex-high`: Uses the default Codex high model

### Auto-reminder

A PostToolUse hook fires after `gh pr create` and reminds you to run `/codex-review`. The hook is configured in `.claude/settings.local.json`.
