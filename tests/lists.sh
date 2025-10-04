#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${TESTS%"/tests"}"
    UTILS="${ROOT}/utils"
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi

# shellcheck source="../utils/logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="../utils/color.sh"
source "${UTILS}/color.sh"
# shellcheck source="../utils/lists.sh"
source "${UTILS}/lists.sh"

echo "Testing functions in lists.sh"
echo ""

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_colors

    # Test data
    test_items=(
        "apple"
        "apricot"
        "banana"
        "berry"
        "cherry"
        "date"
        "grape"
    )

    # Track test results
    test1_pass=0
    test2_pass=0
    test3_pass=0
    test4_pass=0
    test5_pass=0
    test6_pass=0
    test7_pass=0
    test8_pass=0

    log ""
    log "${BOLD}retain_prefixes_ref()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given array: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Retain items starting with ${GREEN}'a'${RESET} or ${GREEN}'b'${RESET}:"
    result=$(retain_prefixes_ref test_items "a" "b")
    result_trimmed=$(echo "$result" | tr '\n' ' ' | sed 's/ $//')
    log "${DIM}${result_trimmed}${RESET}"
    log ""
    log "Expected: apple apricot banana berry"
    [[ "$result_trimmed" == "apple apricot banana berry" ]] && test1_pass=1
    log ""

    log ""
    log "${BOLD}retain_prefixes_val()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given items piped from stdin: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Retain items starting with ${GREEN}'c'${RESET} or ${GREEN}'d'${RESET}:"
    result=$(printf '%s\n' "${test_items[@]}" | retain_prefixes_val "c" "d")
    result_trimmed=$(echo "$result" | tr '\n' ' ' | sed 's/ $//')
    log "${DIM}${result_trimmed}${RESET}"
    log ""
    log "Expected: cherry date"
    [[ "$result_trimmed" == "cherry date" ]] && test2_pass=1
    log ""

    log ""
    log "${BOLD}filter_prefixes_ref()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given array: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Filter out items starting with ${RED}'a'${RESET} or ${RED}'b'${RESET}:"
    result=$(filter_prefixes_ref test_items "a" "b")
    result_trimmed=$(echo "$result" | tr '\n' ' ' | sed 's/ $//')
    log "${DIM}${result_trimmed}${RESET}"
    log ""
    log "Expected: cherry date grape"
    [[ "$result_trimmed" == "cherry date grape" ]] && test3_pass=1
    log ""

    log ""
    log "${BOLD}filter_prefixes_val()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given items piped from stdin: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Filter out items starting with ${RED}'g'${RESET}:"
    result=$(printf '%s\n' "${test_items[@]}" | filter_prefixes_val "g")
    result_trimmed=$(echo "$result" | tr '\n' ' ' | sed 's/ $//')
    log "${DIM}${result_trimmed}${RESET}"
    log ""
    log "Expected: apple apricot banana berry cherry date"
    [[ "$result_trimmed" == "apple apricot banana berry cherry date" ]] && test4_pass=1
    log ""

    log ""
    log "${BOLD}list_contains_ref()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given array: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Check if array contains ${GREEN}'banana'${RESET}:"
    if list_contains_ref test_items "banana"; then
        log "${DIM}Found${RESET}"
        test5_pass=1
    else
        log "${DIM}Not found${RESET}"
    fi
    log ""
    log "Expected: Found"
    log ""
    log "Check if array contains ${RED}'orange'${RESET}:"
    if list_contains_ref test_items "orange"; then
        log "${DIM}Found${RESET}"
    else
        log "${DIM}Not found${RESET}"
        test6_pass=1
    fi
    log ""
    log "Expected: Not found"
    log ""

    log ""
    log "${BOLD}list_contains_val()${RESET} function"
    log "-----------------------------------"
    log ""
    log "Given items piped from stdin: ${CYAN}${test_items[*]}${RESET}"
    log ""
    log "Check if list contains ${GREEN}'cherry'${RESET}:"
    if printf '%s\n' "${test_items[@]}" | list_contains_val "cherry"; then
        log "${DIM}Found${RESET}"
        test7_pass=1
    else
        log "${DIM}Not found${RESET}"
    fi
    log ""
    log "Expected: Found"
    log ""
    log "Check if list contains ${RED}'mango'${RESET}:"
    if printf '%s\n' "${test_items[@]}" | list_contains_val "mango"; then
        log "${DIM}Found${RESET}"
    else
        log "${DIM}Not found${RESET}"
        test8_pass=1
    fi
    log ""
    log "Expected: Not found"
    log ""

    log ""
    log "${BOLD}${GREEN}Summary${RESET}"
    log "-------"
    log ""
    if (( test1_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}retain_prefixes_ref${RESET} - keeps matching items from array reference"
    else
        log "  ${RED}✗${RESET} ${BOLD}retain_prefixes_ref${RESET} - keeps matching items from array reference"
    fi
    if (( test2_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}retain_prefixes_val${RESET} - keeps matching items from stdin"
    else
        log "  ${RED}✗${RESET} ${BOLD}retain_prefixes_val${RESET} - keeps matching items from stdin"
    fi
    if (( test3_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}filter_prefixes_ref${RESET} - removes matching items from array reference"
    else
        log "  ${RED}✗${RESET} ${BOLD}filter_prefixes_ref${RESET} - removes matching items from array reference"
    fi
    if (( test4_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}filter_prefixes_val${RESET} - removes matching items from stdin"
    else
        log "  ${RED}✗${RESET} ${BOLD}filter_prefixes_val${RESET} - removes matching items from stdin"
    fi
    if (( test5_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}list_contains_ref${RESET} - finds 'banana' in array"
    else
        log "  ${RED}✗${RESET} ${BOLD}list_contains_ref${RESET} - finds 'banana' in array"
    fi
    if (( test6_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}list_contains_ref${RESET} - correctly reports 'orange' not in array"
    else
        log "  ${RED}✗${RESET} ${BOLD}list_contains_ref${RESET} - correctly reports 'orange' not in array"
    fi
    if (( test7_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}list_contains_val${RESET} - finds 'cherry' in stdin"
    else
        log "  ${RED}✗${RESET} ${BOLD}list_contains_val${RESET} - finds 'cherry' in stdin"
    fi
    if (( test8_pass )); then
        log "  ${GREEN}✓${RESET} ${BOLD}list_contains_val${RESET} - correctly reports 'mango' not in stdin"
    else
        log "  ${RED}✗${RESET} ${BOLD}list_contains_val${RESET} - correctly reports 'mango' not in stdin"
    fi
    log ""

    remove_colors
fi
