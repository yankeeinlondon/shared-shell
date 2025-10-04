#!/usr/bin/env bash

# matches_glob <pattern> <content>
#
# Tests whether <content> matches the glob <pattern>.
# Returns 0 (true) if match, 1 (false) if no match.
#
# If pattern contains no glob wildcards (* ? [ ]), it's treated as an exact match.
#
# Examples:
#   matches_glob "*debug*" "my_debug_func" → returns 0
#   matches_glob "is_*" "is_empty" → returns 0
#   matches_glob "link*" "unlink" → returns 1
#   matches_glob "trim" "trim" → returns 0
#   matches_glob "trim" "trim_ref" → returns 1
function matches_glob() {
    local -r pattern="${1:?no pattern provided to matches_glob}"
    local -r content="${2:?no content provided to matches_glob}"

    # Check if pattern contains glob wildcards
    if [[ "$pattern" == *[\*\?\[]* ]]; then
        # Has wildcards - use glob matching
        # shellcheck disable=SC2053
        if [[ "$content" == $pattern ]]; then
            return 0
        else
            return 1
        fi
    else
        # No wildcards - use exact string comparison
        if [[ "$content" == "$pattern" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# report_fns_to_console [pattern]
#
# Displays the available functions found in the utils directory
# in a console friendly format.
#
# If [pattern] is provided, only functions whose names match the
# glob pattern will be displayed. Pattern examples:
#   - "*debug*" - functions containing "debug"
#   - "is_*" - functions starting with "is_"
#   - "*_api" - functions ending with "_api"
function report_fns_to_console() {
    local -r pattern="${1:-}"
    if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
        UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [[ "${UTILS}" == *"/utils" ]];then
            ROOT="${UTILS%"/utils"}"
        else
            ROOT="$UTILS"
        fi
    else
        ROOT="${ADAPTIVE_SHELL}"
        UTILS="${ROOT}/utils"
    fi
    # get a the JSON payload defining the functions which
    # matches the type `FunctionSummary` defined in `/static-types.ts`
    local -r fns="$("${ROOT}/static.sh" "${UTILS}")"

    # shellcheck source="../color.sh"
    source "${UTILS}/color.sh"
    # enable all ENV variables for colorization
    setup_colors

    # shellcheck source="../utils/errors.sh"
    source "${UTILS}/errors.sh"
    # shellcheck source="../utils/typeof.sh"
    source "${UTILS}/typeof.sh"
    # shellcheck source="../utils/link.sh"
    source "${UTILS}/link.sh"

    # First pass: collect filtered function names and metadata for duplicate detection
    local -a collected_names=()
    local -A name_locations=()
    local name file relative_path start end

    while IFS= read -r func_json; do
        [ -z "$func_json" ] && continue

        name=$(echo "$func_json" | jq -r '.name')

        # Filter by pattern if provided
        if [ -n "$pattern" ]; then
            if ! matches_glob "$pattern" "$name"; then
                continue
            fi
        fi

        file=$(echo "$func_json" | jq -r '.file')
        start=$(echo "$func_json" | jq -r '.start')

        # Calculate relative path for display
        if [[ "$file" == /* ]]; then
            relative_path="${file#${ROOT}/}"
        else
            relative_path="${file#./}"
        fi

        collected_names+=("$name")

        # Store location info (append if duplicate)
        if [[ -n "${name_locations[$name]:-}" ]]; then
            name_locations[$name]="${name_locations[$name]}|${relative_path}:${start}"
        else
            name_locations[$name]="${relative_path}:${start}"
        fi
    done < <(echo "$fns" | jq -r '.functions | sort_by(.name) | .[] | @json')

    # Detect duplicates
    local duplicates=""
    if [ ${#collected_names[@]} -gt 0 ]; then
        duplicates=$(printf '%s\n' "${collected_names[@]}" | sort | uniq -d)
    fi

    # Display functions
    local name arguments description file start end relative_path absolute_path location_text clickable_link
    while IFS= read -r func_json; do
        # Skip empty lines
        [ -z "$func_json" ] && continue

        # Parse function properties
        name=$(echo "$func_json" | jq -r '.name')

        # Filter by pattern if provided
        if [ -n "$pattern" ]; then
            if ! matches_glob "$pattern" "$name"; then
                continue
            fi
        fi

        arguments=$(echo "$func_json" | jq -r '.arguments')
        description=$(echo "$func_json" | jq -r '.description')
        file=$(echo "$func_json" | jq -r '.file')
        start=$(echo "$func_json" | jq -r '.start')
        end=$(echo "$func_json" | jq -r '.end')

        # Replace \\n with actual newlines in description and indent each line with two spaces (only if not empty)
        if [ -n "$description" ]; then
            description=$(echo "$description" | sed 's/\\\\n/\n/g' | sed 's/^/  /')
        fi

        # Calculate relative path (remove leading ./ or absolute ROOT prefix)
        if [[ "$file" == /* ]]; then
            # File is absolute, make it relative to ROOT
            relative_path="${file#${ROOT}/}"
            absolute_path="$file"
        else
            # File is relative, remove ./ prefix
            relative_path="${file#./}"
            absolute_path="${ROOT}/${relative_path}"
        fi

        # Create location text with line numbers
        location_text="${relative_path} [lines ${start} to ${end}]"

        # Create clickable link using link_file function
        clickable_link=$(link_file "${location_text}" "${absolute_path}")

        # Print function name (always shown)
        if [ -n "$arguments" ]; then
            echo -n -e "${BOLD}${GREEN}${name}${RESET} ${DIM}${arguments}${RESET}"
        else
            echo -n -e "${BOLD}${GREEN}${name}${RESET}"
        fi

        # Print description if present (or just newline if not)
        if [ -n "$description" ]; then
            echo ""
            echo -e "${DIM}${ITALIC}${description}${RESET}"
        else
            echo ""
        fi

        # Print file location with clickable link
        echo -e "  - located in ${BLUE}${clickable_link}${RESET}"

        # Blank line between functions
        echo ""
    done < <(echo "$fns" | jq -r '.functions | sort_by(.name) | .[] | @json')

    # Display duplicate warning at the end if found
    if [ -n "$duplicates" ]; then
        echo -e "${BOLD}${BRIGHT_MAGENTA}Note:${RESET} we detected the following duplicate function names:\n"
        while IFS= read -r dup_name; do
            [ -z "$dup_name" ] && continue
            local locations="${name_locations[$dup_name]}"
            echo -e "  ${BOLD}${YELLOW}${dup_name}${RESET}"
            IFS='|' read -ra locs <<< "$locations"
            for loc in "${locs[@]}"; do
                echo -e "    - ${loc}"
            done
        done <<< "$duplicates"
    fi

}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_fns_to_console "${@}"
fi
