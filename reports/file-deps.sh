#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    REPORTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${REPORTS%"/reports"}"
    UTILS="${ROOT}/utils"
    PROGRAMS="${ROOT}/programs"
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
    REPORTS="${ROOT}/reports"
    PROGRAMS="${ROOT}/programs"
fi

# shellcheck source="../static.sh"
source "${ROOT}/static.sh"
# shellcheck source="../utils/typeof.sh"
source "${ROOT}/utils.sh"


# report_file_dependencies <file 1> <...files> [--json]
#
# Reports the file dependencies of the files passed in
# as parameters. By default it will print in a console
# friendly way leveraging colors appropriately. If you
# prefer to get JSON as output then add `--json` as one
# of the parameters passed in.
function report_file_dependencies() {


    local -a params=("${@}")
    local -a files=()
    local output_json=0

    # Parse parameters - separate files from --json flag
    for param in "${params[@]}"; do
        if [[ "$param" == "--json" ]]; then
            output_json=1
        else
            files+=("$param")
        fi
    done

    setup_colors

    # Validate we have files to process
    if [ "${#files[@]}" -eq 0 ]; then
        if (( output_json )); then
            echo '{"results":[]}'
        else
            log "${RED}Error:${RESET} No files provided"
        fi
        return 1
    fi

    # Process each file and collect results
    local -a results=()
    local file deps

    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            if (( ! output_json )); then
                log "$(red_backing "Error:") file not found: ${BLUE}${file}${RESET}"
            fi
            continue
        fi

        deps=$(file_dependencies "$file")
        results+=("$file|$deps")
    done

    # Output results
    if (( output_json )); then
        # JSON output
        local results_json="["
        local first=1
        local file_path dep_json

        for result in "${results[@]}"; do
            file_path="${result%%|*}"
            dep_json="${result#*|}"

            if [ $first -eq 1 ]; then
                first=0
            else
                results_json+=","
            fi

            # Construct JSON object with file and its dependencies
            results_json+="{\"file\":\"${file_path}\",\"dependencies\":${dep_json}}"
        done
        results_json+="]"

        printf '{"results":%s}\n' "$results_json"
    else
        # Console output
        setup_colors
        local file_path dep_json file_deps func_deps relative_path absolute_path

        log ""
        log "${BOLD}${GREEN}File Dependencies Report${RESET}"
        log "======================="
        log ""

        for result in "${results[@]}"; do
            file_path="${result%%|*}"
            dep_json="${result#*|}"

            # Make the file path relative and clickable
            if [[ "$file_path" == /* ]]; then
                # Absolute path - make relative to ROOT
                relative_path="${file_path#"${ROOT}/"}"
                absolute_path="$file_path"
            else
                # Already relative - resolve to absolute
                # Use realpath or readlink to resolve ./ and ../
                absolute_path="$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")"
                relative_path="${absolute_path#"${ROOT}/"}"
            fi

            # Create clickable link for the file being analyzed
            local clickable_file
            clickable_file=$(link_file "${relative_path}" "${absolute_path}")

            log "${BOLD}${CYAN}${clickable_file}${RESET}"
            log ""

            # Extract file and function dependencies from JSON
            file_deps=$(echo "$dep_json" | jq -r '.files[]' 2>/dev/null)
            func_deps=$(echo "$dep_json" | jq -r '.functions[]' 2>/dev/null)

            if [ -n "$file_deps" ]; then
                log "  ${DIM}Source Dependencies:${RESET}"
                echo "$file_deps" | while IFS= read -r dep; do
                    [ -z "$dep" ] && continue

                    # Expand environment variables in the dependency path
                    local expanded_dep
                    expanded_dep=$(eval "echo \"$dep\"" 2>/dev/null || echo "$dep")

                    # Make dependency path relative and clickable
                    if [[ "$expanded_dep" == /* ]]; then
                        dep_relative="${expanded_dep#"${ROOT}/"}"
                        dep_absolute="$expanded_dep"
                    else
                        dep_relative="$expanded_dep"
                        dep_absolute="${ROOT}/${expanded_dep}"
                    fi

                    # Create clickable link only if file exists
                    if [ -f "$dep_absolute" ]; then
                        local clickable_dep
                        clickable_dep=$(link_file "${dep_relative}" "${dep_absolute}")
                        log "    ${GREEN}•${RESET} ${clickable_dep}"
                    else
                        log "    ${GREEN}•${RESET} ${dep_relative} ${RED}(not found)${RESET}"
                    fi
                done
                log ""
            else
                log "  ${DIM}No source dependencies${RESET}"
                log ""
            fi

            if [ -n "$func_deps" ]; then
                log "  ${DIM}Function Calls:${RESET}"

                # Get the function registry to look up file locations
                local registry
                registry=$(echo "$dep_json" | jq -r '.registry // empty' 2>/dev/null)

                # Display each function with a link to its source file
                echo "$func_deps" | while IFS= read -r func; do
                    [ -z "$func" ] && continue

                    # Look up the file where this function is defined
                    local func_file
                    if [ -n "$registry" ]; then
                        func_file=$(echo "$registry" | jq -r --arg fn "$func" '.[$fn] // empty' 2>/dev/null)
                    fi

                    if [ -n "$func_file" ]; then
                        # Expand environment variables in the function file path
                        local expanded_func_file
                        expanded_func_file=$(eval "echo \"$func_file\"" 2>/dev/null || echo "$func_file")

                        # Make function file path relative and clickable
                        local func_relative func_absolute
                        if [[ "$expanded_func_file" == /* ]]; then
                            func_relative="${expanded_func_file#"${ROOT}/"}"
                            func_absolute="$expanded_func_file"
                        else
                            func_relative="$expanded_func_file"
                            func_absolute="${ROOT}/${expanded_func_file}"
                        fi

                        # Create clickable link showing function name and file
                        if [ -f "$func_absolute" ]; then
                            local clickable_func
                            clickable_func=$(link_file "${func}() → ${func_relative}" "${func_absolute}")
                            log "    ${GREEN}•${RESET} ${clickable_func}"
                        else
                            log "    ${GREEN}•${RESET} ${func}() → ${func_relative} ${RED}(not found)${RESET}"
                        fi
                    else
                        # Function not in registry (external command or built-in)
                        log "    ${GREEN}•${RESET} ${func}()"
                    fi
                done
                log ""
            else
                log "  ${DIM}No function calls detected${RESET}"
                log ""
            fi
        done

        remove_colors
    fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_file_dependencies "${@}"
fi
