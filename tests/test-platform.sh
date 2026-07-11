#!/usr/bin/env bash
#
# Platform compatibility tests for Cursor Chat Recovery Tool
# Tests the main script's behavior without duplicating its code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/../cursor-chat-recovery.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; tests_failed=1; }

tests_failed=0

echo "========================================="
echo "Cursor Chat Recovery - Platform Tests"
echo "========================================="
echo ""

# Test 1: Environment
echo "Test 1: Environment"
echo "  OSTYPE: $OSTYPE"
echo "  SHELL: $SHELL"
echo "  PWD: $PWD"
echo ""

# Test 2: Required Commands
echo "Test 2: Required Commands"
for cmd in bash stat strings du grep sed cp mktemp; do
    command -v "$cmd" &>/dev/null && pass "$cmd" || fail "$cmd NOT found"
done
echo ""
echo "Optional:"
command -v sqlite3 &>/dev/null && pass "sqlite3 (merge feature)" || warn "sqlite3 (merge disabled)"
echo ""

# Test 3: Main Script Exists
echo "Test 3: Main Script"
if [ ! -f "$MAIN_SCRIPT" ]; then
    fail "Script not found: $MAIN_SCRIPT"
    exit 1
fi
pass "Script found"

[ -x "$MAIN_SCRIPT" ] && pass "Executable" || warn "Not executable (run: chmod +x cursor-chat-recovery.sh)"
echo ""

# Test 4: --version flag
echo "Test 4: --version"
version_output=$("$MAIN_SCRIPT" --version 2>&1)
if [[ "$version_output" == *"Cursor Chat Recovery Tool"* ]]; then
    pass "$version_output"
else
    fail "--version returned unexpected output"
fi
echo ""

# Test 5: --help flag
echo "Test 5: --help"
help_output=$("$MAIN_SCRIPT" --help 2>&1)
if [[ "$help_output" == *"Usage:"* ]] && [[ "$help_output" == *"--list"* ]] && [[ "$help_output" == *"--restore"* ]]; then
    pass "--help shows usage information"
else
    fail "--help output missing expected content"
fi
echo ""

# Test 6: Invalid flag handling
echo "Test 6: Invalid Flag"
invalid_output=$("$MAIN_SCRIPT" --invalid-flag 2>&1)
exit_code=$?
if [[ "$invalid_output" == *"Unknown option"* ]] && [ $exit_code -ne 0 ]; then
    pass "Invalid flag rejected correctly"
else
    fail "Invalid flag not handled properly"
fi
echo ""

# Test 7: Platform-specific stat command
echo "Test 7: stat Compatibility"
temp=$(mktemp)
if [[ "$OSTYPE" == "darwin"* ]]; then
    stat -f "%Sm" "$temp" &>/dev/null && pass "BSD stat works" || fail "BSD stat failed"
else
    stat -c "%y" "$temp" &>/dev/null && pass "GNU stat works" || fail "GNU stat failed"
fi
rm -f "$temp"
echo ""

# Test 8: Windows-specific (if applicable)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "mingw"* ]]; then
    echo "Test 8: Windows-Specific"
    [ -n "$APPDATA" ] && pass "APPDATA set" || fail "APPDATA not set"
    [ -n "$LOCALAPPDATA" ] && pass "LOCALAPPDATA set" || warn "LOCALAPPDATA not set"
    command -v cygpath &>/dev/null && pass "cygpath available" || warn "cygpath not available"
    command -v tasklist.exe &>/dev/null && pass "tasklist.exe available" || warn "tasklist.exe not found"
    echo ""
fi

# Test 9: Dry-run guards precede all mutation paths
echo "Test 9: Dry-run Mutation Guards"
cursor_check_body=$(sed -n '/^check_cursor_running()/,/^}/p' "$MAIN_SCRIPT")
merge_body=$(sed -n '/^merge_chat_histories()/,/^}/p' "$MAIN_SCRIPT")

cursor_guard_line=$(printf '%s\n' "$cursor_check_body" | grep -n 'if \[ "$DRY_RUN" = true \]' | head -1 | cut -d: -f1)
kill_line=$(printf '%s\n' "$cursor_check_body" | grep -n 'killall\|taskkill' | head -1 | cut -d: -f1)
merge_guard_line=$(printf '%s\n' "$merge_body" | grep -n 'if \[ "$DRY_RUN" = true \]' | head -1 | cut -d: -f1)
backup_line=$(printf '%s\n' "$merge_body" | grep -n 'backup_database' | head -1 | cut -d: -f1)

if [ -n "$cursor_guard_line" ] && [ -n "$kill_line" ] && [ "$cursor_guard_line" -lt "$kill_line" ]; then
    pass "Dry-run exits before Cursor termination"
else
    fail "Dry-run guard must precede Cursor termination"
fi

if [ -n "$merge_guard_line" ] && [ -n "$backup_line" ] && [ "$merge_guard_line" -lt "$backup_line" ]; then
    pass "Dry-run exits before merge backup/write"
else
    fail "Dry-run guard must precede merge mutations"
fi
echo ""

# Summary
echo "========================================="
echo "Summary"
echo "========================================="
if [ $tests_failed -eq 0 ]; then
    pass "All tests passed!"
else
    fail "Some tests failed"
fi
echo ""
echo "Quick test:"
echo "  bash $MAIN_SCRIPT --list your-project-name"
echo ""

exit $tests_failed
