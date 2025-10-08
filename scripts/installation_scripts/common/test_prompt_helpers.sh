#!/usr/bin/env bash
# Simple unit-style tests for common prompt helpers
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$COMMON_DIR/common_ui.sh"

# Preload test input into stdin for sequential consumption by read
# Lines correspond to: (empty for default), y, n, true, false
TMP_INPUT_FILE="$(mktemp)"
cat > "$TMP_INPUT_FILE" <<'EOF'

y
n
true
false
EOF

# Redirect stdin from the prepared input file for the remainder of the script
exec 0<"$TMP_INPUT_FILE"

# Test prompt_with_default: Provide empty input -> should pick default
TEST_TMP_VAR=""
prompt_with_default "Test prompt" "mydefault" TEST_TMP_VAR
if [ "$TEST_TMP_VAR" != "mydefault" ]; then
    echo "prompt_with_default: expected 'mydefault' got '$TEST_TMP_VAR'"
    rm -f "$TMP_INPUT_FILE"
    exit 2
fi

echo "prompt_with_default default handling: OK"


# validate_yn: first input 'y' should return 0
if validate_yn "Yes?" "y"; then
    : # success
else
    echo "validate_yn: expected success for 'y'"
    rm -f "$TMP_INPUT_FILE"
    exit 3
fi

# validate_yn: next input 'n' should return 1
if validate_yn "Yes?" "n"; then
    echo "validate_yn: expected failure for 'n'"
    rm -f "$TMP_INPUT_FILE"
    exit 4
else
    : # expected failure
fi

echo "validate_yn basic checks: OK"

# validate_tf: next inputs true/false

if validate_tf "True?" "true"; then
    :
else
    echo "validate_tf: expected success for 'true'"
    rm -f "$TMP_INPUT_FILE"
    exit 5
fi

if validate_tf "True?" "false"; then
    echo "validate_tf: expected failure for 'false'"
    rm -f "$TMP_INPUT_FILE"
    exit 6
else
    :
fi

rm -f "$TMP_INPUT_FILE"
echo "validate_tf basic checks: OK"

echo "All prompt helper tests passed."
exit 0
