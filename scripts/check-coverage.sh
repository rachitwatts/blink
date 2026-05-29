#!/bin/bash
#
# Coverage ratchet for the core logic layer (Services + Models + Shared).
#
# We gate the LOGIC layer, not overall app coverage: the SwiftUI Views are a
# large, mostly-untested denominator that would drag an overall-% gate down and
# trip on any new view code. Bugs cluster in the logic layer — that's what we
# protect here. Raise FLOOR as coverage climbs.
#
# Usage: check-coverage.sh [xcresult-path] [floor-percent]

set -euo pipefail

RESULT="${1:-build/TestResults-Unit.xcresult}"
FLOOR="${2:-70.0}"

if [ ! -d "$RESULT" ]; then
  echo "::error::Coverage result bundle not found: $RESULT"
  exit 1
fi

PCT=$(xcrun xccov view --report --json "$RESULT" | python3 -c '
import json, sys
data = json.load(sys.stdin)
core = ("/Blink/Services/", "/Blink/Models/", "/Shared/")
covered = total = 0
for t in data.get("targets", []):
    for f in t.get("files", []):
        path = f.get("path", "")
        if any(c in path for c in core):
            covered += f["coveredLines"]
            total += f["executableLines"]
print(f"{(100.0*covered/total) if total else 0:.2f}")
')

echo "Core logic coverage (Services+Models+Shared): ${PCT}%  (floor: ${FLOOR}%)"

# Float comparison via awk (bash can't do decimals).
if awk "BEGIN { exit !($PCT < $FLOOR) }"; then
  echo "::error::Core coverage ${PCT}% is below the floor of ${FLOOR}%. Add tests or justify lowering the floor."
  exit 1
fi
echo "OK: core coverage meets the floor."
