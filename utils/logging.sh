#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL}" ] || [[ "${ADAPTIVE_SHELL}" == "" ]]; then
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

# shellcheck source="../color.sh"
source "${ROOT}/color.sh"

# log
#
# Logs the parameters passed to STDERR
function log() {
    printf "%b\\n" "${*}" >&2
}


function out() {
    printf "%b\\n" "${*}"
}

function panic() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}" || echo "unknown"

    log "\n  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$code${RESET}${BOLD} →${RESET} ${msg}"
    log ""
    for i in "${!BASH_SOURCE[@]}"; do
        if ! contains "errors.sh" "${BASH_SOURCE[$i]}"; then
            log "    - ${FUNCNAME[$i]}() ${ITALIC}${DIM}at line${RESET} ${BASH_LINENO[$i-1]} ${ITALIC}${DIM}in${RESET} $(error_path "${BASH_SOURCE[$i]}")"
        fi
    done
    log ""
    exit $code
}

# debug <fn> <msg> <...>
#
# Logs to STDERR when the DEBUG env variable is set
# and not equal to "false".
function debug() {
    if [ -z "${DEBUG:-}" ] || [[ "${DEBUG:-}" == "" ]]; then
        return 0
    else
        if (( $# > 1 )); then
            local fn="$1"

            shift
            local regex=""
            local lower_fn=""
            lower_fn=$(echo "$fn" | tr '[:upper:]' '[:lower:]')
            regex="(.*[^a-z]+|^)$lower_fn($|[^a-z]+.*)"

            if [[ "${DEBUG}" == "true" || "${DEBUG}" =~ $regex ]]; then
                log "       ${GREEN}◦${RESET} ${BOLD}${fn}()${RESET} → ${*}"
            fi
        else
            log "       ${GREEN}DEBUG: ${RESET} → ${*}"
        fi
    fi
}

# error <msg>
#
# sends a formatted error message to STDERR
function error() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}"

    log "\n  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$code${RESET}${BOLD} →${RESET} ${msg}" && return $code
}
