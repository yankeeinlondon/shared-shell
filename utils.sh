#!/usr/bin/env bash

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

if [[ "$(whoami)" == "root" ]]; then
    export SUDO=""
else
    export SUDO="sudo"
fi

# shellcheck source="./color.sh"
source "${UTILS}/color.sh";
# shellcheck source="./utils/typeof.sh"
source "${UTILS}/typeof.sh"
# shellcheck source="./utils/logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="./utils/errors.sh"
source "${UTILS}/errors.sh"
# shellcheck source="./utils/text.sh"
source "${UTILS}/text.sh"
# shellcheck source="./utils/filesystem.sh"
source "${UTILS}/filesystem.sh"
# shellcheck source="./utils/os.sh"
source "${UTILS}/os.sh"
# shellcheck source="./utils/functions.sh"
source "${UTILS}/functions.sh"
# shellcheck source="./utils/lists.sh"
source "${UTILS}/lists.sh"
# shellcheck source="./utils/detection.sh"
source "${UTILS}/detection.sh"
# shellcheck source="./utils/link.sh"
source "${UTILS}/link.sh"

# confirm(question, [default])
#
# Asks the user to confirm yes or no and returns TRUE when they answer yes
function confirm() {
    local -r question="${1:?confirm() missing question}"
    local -r default="${2:-y}"
    local response

    # Display prompt with printf to avoid zsh/bash compatibility issues
    if [[ $(lc "$default") == "y" ]]; then
        printf "%s (Y/n) " "$question"
    else
        printf "%s (y/N) " "$question"
    fi

    # Read input without -p (compatible with all shells)
    read -r response

    # Rest of the logic remains the same...
    if [[ $(lc "$default") == "y" ]]; then
        [[ $(lc "$response") =~ ^n(no)?$ ]] && return 1 || return 0
    else
        [[ $(lc "$response") =~ ^y(es)?$ ]] && return 0 || return 1
    fi
}

# is_numeric() <candidate>
#
# returns 0/1 based on whether <candidate> is numeric
function is_numeric() {
    local -r val="$1"
        if ! [[ "$val" =~ ^[0-9]+$ ]]; then
            return 1
        else
            return 0
        fi
}

function is_string() {
  local -r val="$1"
  if [[ -z "$val" ]]; then
    return 1
  else
    if [[ "$val" =~ ^[a-zA-Z]{1}.*$ ]]; then
      return 0
    else
      return 1
    fi
  fi
}

function is_bound() {
    local -n __test_by_ref=$1 2>/dev/null || { debug "is_bound" "unbounded ref";  return 1; }
    # local -r by_val="${1}:-"
    local name="${!__test_by_ref:-}"
    local -r arithmetic='→+-=><%'
    if has_characters "${arithmetic}" "$1"; then
        debug "is_bound" "${name} is NOT bound"
        return 1
    else
        local idx
        eval "idx=\${$1:-}" 2>/dev/null || idx=""
        local a
        eval "a=\${__test_by_ref@a}" 2>/dev/null || a=""

        if [[ -z "${idx}${a}" ]]; then
            debug "is_bound" "${name} is NOT bound: ${idx}, ${a}"
            return 1
        else
            debug "is_bound" "${name} IS bound: ${idx}, ${a}"
            return 0
        fi
    fi
}

# append_to_path <path>
#
# Appends the path passed in to the PATH env variable
function append_to_path() {
    local -r new="${1:?No path passed into append_to_path()!}"
    local -r current="${PATH:-}"
    local -r newPath="${current};${new}"

    export PATH="${newPath}"
    echo "${newPath}"
}



function not_in_package_json() {
    local find="${1:?find string missing in call to not_in_package_json}"
    local -r pkg="$(get_file "./package.json")"

    if contains "${find}" "${pkg}"; then
        return 1;
    else
        return 0;
    fi
}

# determine which "npm based" package manager to use
function choose_npm_pkg_manager() {
    if file_exists "./pnpm-lock.yaml"; then
        echo "pnpm"
    elif file_exists "./package-lock.json"; then
        echo "npm"
    elif file_exists "./yarn.lock"; then
        echo "yarn"
    else
        echo "pnpm"
    fi
}

function npm_install_devdep() {
    local pkg="${1:?no package sent to npm_install_devdep}"
    local -r mgr="$(choose_npm_pkg_manager)"

    if in_package_json "\"$pkg\":"; then
        log "- ${BOLD}${pkg}${RESET} already installed"
    else
        log ""
        if "${mgr}" install -D "${pkg}"; then
            log ""
            log "- installed ${BOLD}${GREEN}${1}${RESET} ${ITALIC}using${RESET} ${mgr}"
        else
            log "- problems installing ${RED}${1}${RESET}"
        fi
    fi
}


# add_to_rc(text, [skip_if])
#
# Adds text to the console's `rc` file if it doesn't already
# exist. Optionally the user may provide a "skip_if" value and
# if they do then the addition of text will also _not_ happen
# if that text is found.
function add_to_rc() {
    local -r shell="$(get_shell)"
    local -r text="${1:?No text content passed to add_to_shell() function!}"
    local -r skip_if="${2:-}"

    # Determine the appropriate rc file
    local rc_file
    case "$shell" in
        bash)   rc_file="$HOME/.bashrc" ;;
        zsh)    rc_file="$HOME/.zshrc" ;;
        fish)   rc_file="$HOME/.config/fish/config.fish" ;;
        nu)     rc_file="$HOME/.config/nushell/config.nu" ;;
        *)      echo "Unsupported shell: $shell" >&2; return 1 ;;
    esac

    # Check if text already exists
    if grep -qF -- "$text" "$rc_file" 2>/dev/null; then
        return 0
    fi

    # Check skip_if condition if provided
    if [[ -n "$skip_if" ]] && grep -qF -- "$skip_if" "$rc_file" 2>/dev/null; then
        return 0
    fi

    # Create parent directory if needed (for fish/nushell)
    mkdir -p "$(dirname "$rc_file")" || {
        echo "Error: Failed to create directory for $rc_file" >&2
        return 1
    }

    # Append the text with proper newline handling
    printf "\n%s\n" "$text" >> "$rc_file" || {
        echo "${RED}Error:${RESET} Failed to write to $rc_file" >&2
        return 1
    }

    return 0
}

# set_env(var, value)
#
# sets an ENV variables value but ONLY if it was previously not set
function set_env() {
    local -r VAR="${1:?no variable name passed to set_env!}"
    local -r VAL="${2:?no value passed to set_env!}"

    if is_empty "${VAR}"; then
        export "${VAR}"="${VAL}"
    fi
}



# get_arch()
#
# Gets the system architecture in standardized format
function get_arch() {
    case $(os) in
        linux|macos)
            local arch
            arch=$(uname -m)
            # Normalize architecture names
            case $arch in
                x86_64)    echo "x86_64" ;;
                aarch64)   echo "arm64" ;;
                armv7l)    echo "armv7" ;;
                armv6l)    echo "armv6" ;;
                *)         echo "$arch" ;;
            esac
            ;;
        windows)
            # Check environment variables first
            if [ -n "$PROCESSOR_ARCHITECTURE" ]; then
                case "$PROCESSOR_ARCHITECTURE" in
                    AMD64) echo "x86_64" ;;
                    ARM64) echo "arm64" ;;
                    *)     echo "$PROCESSOR_ARCHITECTURE" ;;
                esac
            else
                # Fallback to PowerShell command
                powershell.exe -Command "[System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLower()"
            fi
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

function get_filename_starting_with() {
    local -r file_pattern="${1:?No file pattern provided to get_filename_starting_with()!}"
    local -r dir="${2-${PWD}}"

    # Find first matching file in alphabetical order
    find "$dir" -maxdepth 1 -type f -name "${file_pattern}*" -printf '%f\n' 2>/dev/null | sort | head -n1
}

function get_ssh_client() {
    # Check common SSH environment variables
    if [[ -n "${SSH_CONNECTION}" ]]; then
        echo "${SSH_CONNECTION}" | awk '{print $1}'
        return
    fi

    if [[ -n "${SSH_CLIENT}" ]]; then
        echo "${SSH_CLIENT}" | awk '{print $1}'
        return
    fi

    # Check `who` command for SSH connections
    if command -v who &>/dev/null; then
        SSH_IP=$(who -m | awk '{print $NF}' | tr -d '()')
        if [[ "${SSH_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "${SSH_IP}"
            return
        fi
    fi

    # Check `netstat` or `ss` for active SSH connections
    if command -v netstat &>/dev/null; then
        SSH_IP=$(netstat -tn | awk '/:22 / {print $5}' | cut -d: -f1 | head -n 1)
        if [[ -n "${SSH_IP}" ]]; then
            echo "${SSH_IP}"
            return
        fi
    elif command -v ss &>/dev/null; then
        SSH_IP=$(ss -tn | awk '/:22 / {print $5}' | cut -d: -f1 | head -n 1)
        if [[ -n "${SSH_IP}" ]]; then
            echo "${SSH_IP}"
            return
        fi
    fi

    # Check `last` command for recent SSH logins (macOS compatibility)
    if command -v last &>/dev/null; then
        # macOS `last` doesn't support `-i`, so we parse the output differently
        SSH_IP=$(last | awk '/still logged in/ {print $3}' | head -n 1)
        if [[ "${SSH_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "${SSH_IP}"
            return
        fi
    fi

    # If no IP is found, return an empty string
    echo ""
    return 1
}


function add_completion() {
    local -r name="${1:?No name was provided to add_completion}"
    local -r completion_text="${2:?No completion text passed to add_completion}";
    local -r shell="$(get_shell)";
    local filename
    filename="${HOME}/.completions/_${name}"

    if file_exists "${filename}"; then
        echo "${filename}"
    fi

    if ! dir_exists "${HOME}/.completions"; then
        mkdir "${HOME}/.completions" &>/dev/null || ( echo "Problems creating completions directory" && exit 1 )
        printf "%s" "# Completions\n\nA directory for shell completion scripts" > "${HOME}/.completions/README.md"
        log "- created completions directory at ${BOLD}${BLUE}~/.completions${RESET}"
        log "- this directory will be used for autocomplete completions"
        log ""
    fi

    echo "${completion_text}" > "$filename"
}




# get_tui() → [whiptail|dialog|ERROR]
#
# tests whether "whiptail" or "display"
# (https://invisible-island.net/dialog/) packages are
# available on the execution platform.
#
# For PVE hosts "whiptail" should always be available.
function get_tui() {
    if has_command "whiptail"; then
        debug "get_tui" "has whiptail"
        return 0
    elif has_command "dialog"; then
        debug "get_tui" "no whiptail but has dialog"
        return 0
    else
        debug "get_tui()" "Neither ${GREEN}whiptail${RESET} nor ${GREEN}dialog${RESET} found on host! One of these is required for the TUI of Moxy to run."
        return 1
    fi
}


function get_ssh_connection() {
    if [[ -n "${SSH_CONNECTION}" ]]; then

        # shellcheck disable=SC2206
        local arr=(${SSH_CONNECTION})

        # Verify that we have exactly four parts.
        if [[ ${#arr[@]} -eq 4 ]]; then
            local client_ip="${arr[0]}"
            # local client_port="${arr[1]}"
            local server_ip="${arr[2]}"
            local server_port="${arr[3]}"

            echo "${client_ip} → ${server_ip} (port ${server_port})"
            return 0
        else
            echo "Error: SSH_CONNECTION does not contain exactly four parts." >&2
            return 1
        fi
    fi

    return 1
}



