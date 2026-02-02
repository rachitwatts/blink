#!/bin/bash

# Blink Automated Test Harness
# Runs all automated tests: unit tests and AppleScript integration tests
#
# Usage:
#   ./scripts/run-tests.sh           # Run all tests
#   ./scripts/run-tests.sh unit      # Run only unit tests
#   ./scripts/run-tests.sh apple     # Run only AppleScript tests
#   ./scripts/run-tests.sh --help    # Show help

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HELPERS_DIR="$SCRIPT_DIR/test-helpers"

# Test results
UNIT_PASSED=0
UNIT_FAILED=0
APPLE_PASSED=0
APPLE_FAILED=0

# ------------------------------------------------------------------------------
# Permission Check
# ------------------------------------------------------------------------------

check_accessibility_permission() {
    local result=$(osascript -e 'tell application "System Events" to return name of first process' 2>&1)

    if [[ "$result" == *"not allowed assistive access"* ]] || [[ "$result" == *"-1719"* ]]; then
        return 1
    else
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_blink_running() {
    if pgrep -x "Blink" > /dev/null; then
        return 0
    else
        return 1
    fi
}

start_blink() {
    print_info "Starting Blink..."

    # Build if needed
    if [ ! -d "$PROJECT_DIR/build/Build/Products/Debug/Blink.app" ]; then
        print_info "Building Blink first..."
        cd "$PROJECT_DIR"
        xcodegen generate 2>/dev/null || true
        xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug build -quiet
    fi

    # Launch the app
    open "$PROJECT_DIR/build/Build/Products/Debug/Blink.app"

    # Wait for it to start
    for i in {1..10}; do
        if check_blink_running; then
            print_success "Blink started"
            sleep 1  # Give it time to fully initialize
            return 0
        fi
        sleep 0.5
    done

    print_failure "Failed to start Blink"
    return 1
}

stop_blink() {
    print_info "Stopping Blink..."
    pkill -x "Blink" 2>/dev/null || true
    sleep 1
}

run_applescript() {
    local script="$1"
    shift
    osascript "$script" "$@" 2>/dev/null
}

# ------------------------------------------------------------------------------
# Unit Tests
# ------------------------------------------------------------------------------

run_unit_tests() {
    print_header "Running Unit Tests"

    cd "$PROJECT_DIR"

    # Generate project if needed
    if [ ! -f "Blink.xcodeproj/project.pbxproj" ]; then
        print_info "Generating Xcode project..."
        xcodegen generate
    fi

    print_info "Running xcodebuild test for BlinkTests..."

    # Clean up stale result bundle
    rm -rf "$PROJECT_DIR/build/TestResults-Unit.xcresult" 2>/dev/null

    if xcodebuild test \
        -project Blink.xcodeproj \
        -scheme Blink \
        -destination 'platform=macOS' \
        -only-testing:BlinkTests \
        -resultBundlePath "$PROJECT_DIR/build/TestResults-Unit.xcresult" \
        2>&1 | tee /tmp/blink-unit-tests.log | grep -E "(Test Case|passed|failed|error:)"; then

        # Count results from log (use head -1 to ensure single value)
        UNIT_PASSED=$(grep -c "Test Case.*passed" /tmp/blink-unit-tests.log 2>/dev/null | head -1 || echo 0)
        UNIT_FAILED=$(grep -c "Test Case.*failed" /tmp/blink-unit-tests.log 2>/dev/null | head -1 || echo 0)
        UNIT_PASSED=${UNIT_PASSED:-0}
        UNIT_FAILED=${UNIT_FAILED:-0}

        if [ "$UNIT_FAILED" -eq 0 ]; then
            print_success "All unit tests passed"
        else
            print_failure "Some unit tests failed"
        fi
    else
        print_failure "Unit tests failed to run"
        UNIT_FAILED=1
    fi
}

# ------------------------------------------------------------------------------
# AppleScript Integration Tests
# ------------------------------------------------------------------------------

run_apple_tests() {
    print_header "Running AppleScript Integration Tests"

    # Check accessibility permission first
    if ! check_accessibility_permission; then
        print_failure "Accessibility permission not granted"
        print_info "Run: ./scripts/test-helpers/check-permissions.sh for instructions"
        APPLE_FAILED=1
        return
    fi

    # Ensure Blink is running
    if ! check_blink_running; then
        start_blink
    fi

    print_info "Accessibility permission verified"
    echo ""

    # Test 1: Menu bar status
    print_info "Test: Menu bar shows timer..."
    local status=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    if [[ "$status" =~ ^[0-9]{2}:[0-9]{2}$ ]] || [[ "$status" =~ ^⏸\ [0-9]{2}:[0-9]{2}$ ]]; then
        print_success "Menu bar shows timer: $status"
        ((APPLE_PASSED++))
    else
        print_failure "Menu bar status unexpected: $status"
        ((APPLE_FAILED++))
    fi

    # Test 2: Pause functionality
    print_info "Test: Pause functionality..."
    local pause_result=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" pause)
    sleep 1
    local status_after_pause=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    if [[ "$status_after_pause" == ⏸* ]]; then
        print_success "Pause works: $status_after_pause"
        ((APPLE_PASSED++))
    else
        print_failure "Pause may not have worked: $status_after_pause"
        ((APPLE_FAILED++))
    fi

    # Test 3: Resume functionality
    print_info "Test: Resume functionality..."
    local resume_result=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" resume)
    sleep 1
    local status_after_resume=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    if [[ "$status_after_resume" != ⏸* ]]; then
        print_success "Resume works: $status_after_resume"
        ((APPLE_PASSED++))
    else
        print_failure "Resume may not have worked: $status_after_resume"
        ((APPLE_FAILED++))
    fi

    # Test 4: Restart session
    print_info "Test: Restart session..."
    sleep 2  # Let timer advance a bit
    local status_before=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    local restart_result=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" restart)
    sleep 1
    local status_after=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    if [[ "$status_after" == "00:00" ]] || [[ "$status_after" == "00:01" ]]; then
        print_success "Restart works: $status_before -> $status_after"
        ((APPLE_PASSED++))
    else
        print_failure "Restart may not have reset: $status_after"
        ((APPLE_FAILED++))
    fi

    # Test 5: Settings window
    print_info "Test: Open settings..."
    run_applescript "$HELPERS_DIR/blink-menu.applescript" settings
    sleep 1
    local settings_status=$(run_applescript "$HELPERS_DIR/blink-settings.applescript" check)
    if [[ "$settings_status" == "OPEN" ]] || [[ "$settings_status" == "NOT_FOUND" ]]; then
        # NOT_FOUND means a window is open but couldn't confirm it's settings
        print_success "Settings window opened"
        ((APPLE_PASSED++))

        # Close settings
        run_applescript "$HELPERS_DIR/blink-settings.applescript" close
        sleep 0.5
    else
        print_failure "Settings window status: $settings_status"
        ((APPLE_FAILED++))
    fi

    # Test 6: Start break now
    print_info "Test: Start break now..."
    run_applescript "$HELPERS_DIR/blink-menu.applescript" start-break
    sleep 2
    local overlay_status=$(run_applescript "$HELPERS_DIR/blink-overlay.applescript" check)
    if [[ "$overlay_status" == VISIBLE* ]]; then
        print_success "Break overlay appeared: $overlay_status"
        ((APPLE_PASSED++))

        # Test 7: Skip break with double Escape
        print_info "Test: Skip break..."
        local skip_result=$(run_applescript "$HELPERS_DIR/blink-overlay.applescript" skip)
        if [[ "$skip_result" == "OK: Skipped" ]]; then
            print_success "Skip works"
            ((APPLE_PASSED++))
        else
            print_failure "Skip result: $skip_result"
            ((APPLE_FAILED++))
        fi
    else
        print_failure "Break overlay not visible: $overlay_status"
        ((APPLE_FAILED++))
    fi

    # Test 8: Timer continues counting
    print_info "Test: Timer increments..."
    local time1=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    sleep 2
    local time2=$(run_applescript "$HELPERS_DIR/blink-menu.applescript" status)
    if [[ "$time1" != "$time2" ]]; then
        print_success "Timer increments: $time1 -> $time2"
        ((APPLE_PASSED++))
    else
        print_failure "Timer not incrementing: $time1 == $time2"
        ((APPLE_FAILED++))
    fi
}

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

print_summary() {
    print_header "Test Summary"

    local total_passed=$((UNIT_PASSED + APPLE_PASSED))
    local total_failed=$((UNIT_FAILED + APPLE_FAILED))

    echo "Unit Tests:        $UNIT_PASSED passed, $UNIT_FAILED failed"
    echo "AppleScript Tests: $APPLE_PASSED passed, $APPLE_FAILED failed"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$total_failed" -eq 0 ]; then
        echo -e "${GREEN}Total: $total_passed passed, $total_failed failed ✓${NC}"
        return 0
    else
        echo -e "${RED}Total: $total_passed passed, $total_failed failed ✗${NC}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

show_help() {
    echo "Blink Automated Test Harness"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all       Run all tests (default)"
    echo "  unit      Run unit tests only"
    echo "  apple     Run AppleScript integration tests only"
    echo "  --help    Show this help"
    echo ""
    echo "Requirements:"
    echo "  - Xcode and xcodebuild"
    echo "  - xcodegen (for project generation)"
    echo "  - Accessibility permission for Terminal (for AppleScript tests)"
    echo ""
    echo "Test Results:"
    echo "  - Unit test results: build/TestResults-Unit.xcresult"
}

main() {
    local command="${1:-all}"

    case "$command" in
        --help|-h)
            show_help
            exit 0
            ;;
        unit)
            run_unit_tests
            print_summary
            ;;
        apple)
            run_apple_tests
            print_summary
            ;;
        all)
            run_unit_tests
            run_apple_tests
            print_summary
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
