#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${TESTS%"/tests"}"
    UTILS="${ROOT}/utils"
    REPORTS="${ROOT}/reports"
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
    REPORTS="${ROOT}/reports"
fi

# shellcheck source="../utils/logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="../utils/color.sh"
source "${UTILS}/color.sh"
# shellcheck source="../reports/file-deps.sh"
source "${REPORTS}/file-deps.sh"

echo "Testing functions in file-deps.sh"
echo ""

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_colors

    # Track test results
    test1_pass=0
    test2_pass=0
    test3_pass=0
    test4_pass=0

    # Create a temporary test file with known dependencies
    temp_test_file=$(mktemp)
    cat > "$temp_test_file" << 'EOF'
#!/usr/bin/env bash

# Test file with dependencies
source "${ROOT}/utils/color.sh"
source "${ROOT}/utils/text.sh"

# Some function calls
setup_colors
log "Hello"
trim "  test  "
rgb_text "255 0 0" "red text"
EOF

    log ""
    log "${BOLD}file_dependencies()${RESET} from static.sh"
    log "---------------------------------------"
    log ""
    log "Testing dependency extraction on a temp file"
    log ""

    result=$(file_dependencies "$temp_test_file")

    # Check if result contains files where functions are actually defined
    # Note: We now use function-based detection, not literal source statements
    # The test file calls: setup_colors, log, trim, rgb_text
    # These are defined in: utils/color.sh, utils/logging.sh, utils/text.sh
    if echo "$result" | jq -e '.files[] | select(. | endswith("/utils/color.sh"))' >/dev/null 2>&1 && \
       echo "$result" | jq -e '.files[] | select(. | endswith("/utils/logging.sh"))' >/dev/null 2>&1 && \
       echo "$result" | jq -e '.files[] | select(. | endswith("/utils/text.sh"))' >/dev/null 2>&1; then
        test1_pass=1
        log "${GREEN}✓${RESET} Detected source dependencies"
    else
        log "${RED}✗${RESET} Failed to detect source dependencies"
    fi

    # Check if result contains expected function calls
    if echo "$result" | jq -e '.functions[] | select(. == "setup_colors")' >/dev/null 2>&1 && \
       echo "$result" | jq -e '.functions[] | select(. == "log")' >/dev/null 2>&1 && \
       echo "$result" | jq -e '.functions[] | select(. == "trim")' >/dev/null 2>&1; then
        test2_pass=1
        log "${GREEN}✓${RESET} Detected function calls"
    else
        log "${RED}✗${RESET} Failed to detect function calls"
    fi
    log ""

    log ""
    log "${BOLD}report_file_dependencies()${RESET} - Console Output"
    log "------------------------------------------------"
    log ""
    log "Testing console output format:"
    log ""

    # Capture console output
    console_output=$(report_file_dependencies "$temp_test_file" 2>&1)

    if echo "$console_output" | grep -q "Source Dependencies:" && \
       echo "$console_output" | grep -q "Function Calls:"; then
        test3_pass=1
        log "${GREEN}✓${RESET} Console output contains expected sections"
    else
        log "${RED}✗${RESET} Console output missing expected sections"
    fi
    log ""

    log ""
    log "${BOLD}report_file_dependencies()${RESET} - JSON Output"
    log "----------------------------------------------"
    log ""
    log "Testing JSON output format with ${CYAN}--json${RESET} flag:"
    log ""

    # Capture JSON output
    json_output=$(report_file_dependencies "$temp_test_file" --json)

    # Validate JSON structure
    if echo "$json_output" | jq -e '.results[0].file' >/dev/null 2>&1 && \
       echo "$json_output" | jq -e '.results[0].dependencies.files' >/dev/null 2>&1 && \
       echo "$json_output" | jq -e '.results[0].dependencies.functions' >/dev/null 2>&1; then
        test4_pass=1
        log "${GREEN}✓${RESET} JSON output has correct structure"
        log ""
        log "${DIM}Sample output:${RESET}"
        echo "$json_output" | jq '.' | head -20
    else
        log "${RED}✗${RESET} JSON output has incorrect structure"
    fi
    log ""

    # Clean up temp file
    rm -f "$temp_test_file"

    log ""
    log "${BOLD}${GREEN}Summary${RESET}"
    log "-------"
    log ""
    if (( test1_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}file_dependencies${RESET} - correctly detects source dependencies"
    else
        log "  ${RED}✗${RESET} ${BOLD}file_dependencies${RESET} - correctly detects source dependencies"
    fi
    if (( test2_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}file_dependencies${RESET} - correctly detects function calls"
    else
        log "  ${RED}✗${RESET} ${BOLD}file_dependencies${RESET} - correctly detects function calls"
    fi
    if (( test3_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}report_file_dependencies${RESET} - console output format works"
    else
        log "  ${RED}✗${RESET} ${BOLD}report_file_dependencies${RESET} - console output format works"
    fi
    if (( test4_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}report_file_dependencies${RESET} - JSON output format works"
    else
        log "  ${RED}✗${RESET} ${BOLD}report_file_dependencies${RESET} - JSON output format works"
    fi
    log ""

    remove_colors
fi
