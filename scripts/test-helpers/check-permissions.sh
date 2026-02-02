#!/bin/bash

# Check if Terminal has Accessibility permissions
# This is required for AppleScript-based UI testing

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking Accessibility permissions..."
echo ""

# Try a simple AppleScript that requires accessibility
RESULT=$(osascript -e 'tell application "System Events" to return name of first process' 2>&1)

if [[ "$RESULT" == *"not allowed assistive access"* ]] || [[ "$RESULT" == *"-1719"* ]]; then
    echo -e "${RED}✗ Accessibility permission NOT granted${NC}"
    echo ""
    echo "To run automated UI tests, you need to grant Accessibility permission:"
    echo ""
    echo "1. Open System Settings"
    echo "2. Go to Privacy & Security → Accessibility"
    echo "3. Click the + button"
    echo "4. Add your terminal app:"
    echo "   - Terminal.app (in /Applications/Utilities/)"
    echo "   - iTerm.app (if using iTerm)"
    echo "   - Warp.app (if using Warp)"
    echo "   - Or whatever terminal you're using"
    echo ""
    echo "You can also run this command to open the settings directly:"
    echo -e "${YELLOW}open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ Accessibility permission granted${NC}"
    echo ""
    echo "You can run the full test suite with:"
    echo "  ./scripts/run-tests.sh"
    echo ""
    exit 0
fi
