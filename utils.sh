#!/usr/bin/env bash


if [[ "$(whoami)" == "root" ]]; then
    export SUDO=""
else
    export SUDO="sudo"
fi

# log
#
# Logs the parameters passed to STDERR
function log() {
    printf "%b\\n" "${*}" >&2
}

# indent(indent_txt, main_content)
function indent() {
    local -r indent_txt="${1:?No indentation text passed to indent()!}"
    local -r main_content="${2:?No main content passed to indent()!}"

    # Convert literal \n to newlines and split lines properly
    printf "%s" "$main_content" | while IFS= read -r line; do
        printf "%s%s\n" "${indent_txt}" "${line}"
    done
}

# find_replace(find, replace, content)
#
# receives a string or RegExp as the "find" parameter and then uses that
# to replace a substring with the "replace" parameter.
# 
# - if the "find" variable is a RegExp it must have a "$1" section identified
# as the text to replace.
#     - the RegExp `/foobar/` would be invalid and should return an error code
#     - the RegExp `/foo(bar)/` is valid as it defines a section to replace
# - if the "find" variable is a string then it's just a simple 
# find-and-replace-all operation.
function find_replace() {
  local find="$1"
  local replace="$2"
  local content="$3"

  # If the "find" looks like /pattern/modifiers, treat it as a regex:
  if [[ $find =~ ^/(.*)/([a-zA-Z]*)$ ]]; then
    local pattern="${BASH_REMATCH[1]}"
    local modifiers="${BASH_REMATCH[2]}"

    # Run Perl so that it does the regex substitution:
    #   - 's/'"$pattern"'/'"$replace"'/'"$modifiers"
    #
    # By using single quotes around s/ and / plus double-quoted expansions
    # for $pattern, $replace, and $modifiers, we ensure Bash doesn't
    # interpret $1, etc. Those make it literally into Perl's regex engine.
    perl -pe 's/'"$pattern"'/'"$replace"'/'"$modifiers" <<< "$content"

  else
    # Otherwise, do a simple string replacement (no capture groups).
    printf "%s" "${content//$find/$replace}"
  fi
}

# debug <fn> <msg> <...>
# 
# Logs to STDERR when the DEBUG env variable is set
# and not equal to "false".
function debug() {
    if [ -z "${DEBUG}" ] || [[ "${DEBUG}" == "" ]]; then
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

# not_empty() <test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is NOT empty and 1 when it is.
function not_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "not_empty(${1})" "was empty, returning 1/false"
        return 1
    else
        debug "not_empty(${1})" "was indeed not empty, returning 0/true"
        return 0
    fi
}


# is_empty() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty() {

    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "is_empty(${1})" "was empty, returning 0/true"
        return 0
    else
        debug "is_empty(${1}))" "was NOT empty, returning 1/false"
        return 1
    fi
}

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

# lc() <str>
#
# converts the passed in <str> to lowercase
function lc() {
    local -r str="${*}"
    debug "lc(${str})" "$(echo "${str}" | tr '[:upper:]' '[:lower:]')"
    echo "${str}" | tr '[:upper:]' '[:lower:]'
}

# contains <find> <content>
# 
# given the "content" string, all other parameters passed in
# will be looked for in this content.
function contains() {
    local -r find="${1}"
    local -r content="${2}"

    if is_empty "$find"; then
        error "contains("", ${content}) function did not recieve a FIND string! This is an invalid call!" 1
    fi

    if is_empty "$content"; then
        debug "contains" "contains(${find},"") received empty content so always returns false"
        return 1;
    fi

    if [[ "${content}" =~ ${find} ]]; then
        debug "contains" "found: ${find}"
        return 0 # successful match
    fi

    debug "contains" "did not find '${find}' in: ${content}"
    return 1
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

# shellcheck source="./color.sh"
source "${HOME}/.config/sh/color.sh";

# shellcheck source="./os.sh"
source "${HOME}/.config/sh/os.sh";




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

function has_characters() {
    local -r char_str="${1:?has_characters() did not recieve a CHARS string!}"
    local -r content="${2:?content expression not passed to has_characters()}"
    # shellcheck disable=SC2207
    local -ra chars=( $(echo "${char_str}" | grep -o .) )
    local found="false"

    if [[ "$content" == *["$char_str"]* ]]; then
        debug "has_characters" "does have some of these characters: '${char_str}'"
        return 0
    else
        debug "has_characters" "does NOT have any of these characters: '${char_str}'"
        return 1
    fi
}

function is_bound() {
    local -n __test_by_ref=$1 2>/dev/null || { debug "is_bound" "unbounded ref";  return 1; }
    local -r by_val="${1}:-"
    local name="${!__test_by_ref}" 2
    local -r arithmetic='→+-=><%'
    if has_characters "${arithmetic}" "$1"; then
        debug "is_bound" "${name} is NOT bound"
        return 1
    else
        local idx=${!1} 2>/dev/null 
        local a="${__test_by_ref@a}" 

        if [[ -z "${idx}${a}" ]]; then
            debug "is_bound" "${name} is NOT bound: ${idx}, ${a}"
            return 1
        else 
            debug "is_bound" "${name} IS bound: ${idx}, ${a}"
            return 0
        fi
    fi
}


# starts_with <look-for> <content>
function starts_with() {
    local -r look_for="${1:?No look-for string provided to starts_with}"
    local -r content="${2:?No content passed to starts_with() fn!}"

    if is_empty "${content}"; then
        debug "starts_with" "starts_with(${look_for}, "") was passed empty content so will always return false"
        return 1;
    fi

    if [[ "${content}" == "${content#"$look_for"}" ]]; then
        debug "starts_with" "false (\"${DIM}${look_for}${RESET}\")"
        return 1; # was not present
    else
        debug "starts_with" "true (\"${DIM}${look_for}${RESET}\")"
        return 0; #: found "look_for"
    fi
}

# find_in_file <filepath> <key>
#
# Finds the first occurance of <key> in the given file
# and if that line is the form "<key>=<value>" then 
# it returns the <value>, otherwise it will return 
# the line.
function find_in_file() {
    local -r filepath="${1:?find_in_file() called but no filepath passed in!}"
    local -r key="${2:?find_in_file() called but key value passed in!}"

    if file_exists "${filepath}"; then
        debug "find_in_file(${filepath})" "file found"
        local found=""

        while read -r line; do
            if not_empty "${line}" && contains "${key}" "${line}"; then
                if starts_with "${key}=" "${line}"; then
                    found="$(strip_leading "${key}=" "${line}")"
                else
                    found="${line}"
                fi
                break
            fi
        done < "$filepath"

        if not_empty "$found"; then
            debug "find_in_file" "found ${key}: ${found}"
            printf "%s" "$found"
            return 0
        else
            debug "find_in_file" "Did not find '${key}' in the file at '${filepath}'"
            echo ""
            return 0
        fi
    else
        debug "find_in_file" "no file at filepath"
        return 1
    fi
}

function get_kernel_version() {
    uname -r
}



function is_mac() { [[ $(uname -s) == Darwin* ]]; }
function is_windows() { [[ $(uname -s) == CYGWIN* || $(uname -s) == MINGW* ]] || command -v cmd.exe &>/dev/null; }


# os
# 
# Will try to detect the operating system of the host computer
# where options are: darwin, linux, windowsnt, 
function os() {
    local -r os_type=$(lc "${OSTYPE}") || "$(lc "$(uname)")" || "unknown"
    case "$os_type" in
        'linux'*)
           echo "linux"
          ;;
        'freebsd'*)
          echo "freebsd"
          ;;
        'windowsnt'*)
          echo "windows"
          ;;
        'darwin'*) 
          echo "macos"
          ;;
        'sunos'*)
          echo "solaris"
          ;;
        'aix'*) 
          echo "aix"
          ;;
        *) echo "unknown/${os_type}"
    esac
}

function is_os() {
  local -r test="${1:?test value for is_os is missing}"

  if [[ "$(os)" == "${test}" ]]; then 
    return 0;
  else 
    return 1;
  fi
}

function get_storage() {
    if is_linux; then
        df --output="source" --output="fstype" --output="avail" --output="pcent" --exclude-type="tmpfs" -h --exclude-type="devtmpfs"

    elif is_mac; then
        df -P -H -a | grep -vE 'TimeMachine|backupdb|^(devfs|autofs|map|localhost:) ' | \
        awk 'BEGIN {print "Filesystem\tType\tUse%\tAvail\tMounted on"} 
            NR>1 {
                # Reconstruct mount point
                mount_point = $6
                for(i=7; i<=NF; i++) mount_point = mount_point " " $i
                
                # Get filesystem type using stat (fast and reliable)
                fstype = "unknown"
                if (system("test -d \"" mount_point "\"") == 0) {
                    cmd = "stat -f %T \"" mount_point "\" 2>/dev/null"
                    cmd | getline fstype
                    close(cmd)
                }
                
                # Network filesystem detection
                if ($1 ~ /^\/\//) fstype = "smb"
                if ($1 ~ /^\/dev\//) fstype = "apfs"
                if ($1 ~ /^\/Applications\//) fstype = "unknown"
                if ($1 ~ /^[a-zA-Z0-9.]+:\//) fstype = "nfs"
                
                # Truncate fields
                fs = length($1) > 30 ? substr($1,1,27) "..." : $1
                mnt = length(mount_point) > 35 ? substr(mount_point,1,37) "..." : mount_point
                
                printf "%s\t%s\t%s\t%s\t%s\n", fs, fstype, $5, $4, mnt
            }' | \
        column -t -s $'\t'

    elif is_windows; then
        powershell.exe -Command "\
            Get-Volume | Where-Object {\$_.DriveType -eq 'Fixed'} | \
            ForEach-Object {
                \$free = [math]::Round(\$_.SizeRemaining / 1GB, 2)
                \$total = [math]::Round(\$_.Size / 1GB, 2)
                \$used = \$total - \$free
                \$pct = if (\$total -gt 0) { [math]::Round((\$used / \$total) * 100) } else { 0 }
                [PSCustomObject]@{
                    Filesystem = \$_.FileSystemType
                    Drive = \$_.DriveLetter + ':'
                    'Size(GB)' = \$total
                    'Free(GB)' = \$free
                    'Use%' = \"\$pct%\"
                }
            }" | \
        awk 'BEGIN {print "Filesystem Type Use% Avail Mounted_on"} 
            NR>1 {
                gsub(/\\r/,"");
                printf "%s %s %s %.1fG %s\n", $3, $1, $5, $4, $2
            }' | \
        column -t
    else
        echo "Unsupported operating system"
        return 1
    fi
}
# has_command <cmd>
#
# checks whether a particular program passed in via $1 is installed 
# on the OS or not (at least within the $PATH)
function has_command() {
    local -r cmd="${1:?cmd is missing}"

    if command -v "${cmd}" &> /dev/null; then
        return 0
    else 
        return 1
    fi
}

# file_exists <filepath>
#
# tests whether a given filepath exists in the filesystem
function file_exists() {
    local filepath="${1:?filepath is missing}"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

# dir_exists <filepath>
#
# tests whether a given directory path exists in the filesystem
function dir_exists() {
    local filepath="${1:?filepath is missing}"

    if [ -d "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

function has_file() {
    local -r filepath="${1:?no filepath passsed to filepath()!}"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}


# validates that the current directory has a package.json file
function has_package_json() {
    local -r filepath="./package.json"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

function is_keyword() {
    local _var=${1:?no parameter passed into is_array}
    local declaration=""
    # shellcheck disable=SC2086
    declaration=$(LC_ALL=C type -t $1)

    if [[ "$declaration" == "keyword" ]]; then
        return 0
    else
        return 1
    fi
}


# get_file() <filepath>
#
# Gets the content from a file at the given <filepath>
function get_file() {
    local -r filepath="${1:?get_file() called but no filepath passed in!}"
    
    if file_exists "${filepath}"; then
        debug "get_file(${filepath})" "getting data"
        local content
        { IFS= read -rd '' content <"${filepath}";}  2>/dev/null
        printf '%s' "${content}"
    else
        debug "get_file(${filepath})" "call to get_file(${filepath}) had invalid filepath"
        return 1
    fi
}


# tests whether a given string exists in the package.json file
# located in the current directory.
function in_package_json() {
    local find="${1:?find string missing in call to in_package_json}"
    local -r pkg="$(get_file "./package.json")"

    if contains "${find}" "${pkg}"; then
        return 0;
    else
        return 1;
    fi
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



# get_shell()
#
# gets the active shell program running inside of 
function get_shell() {
    local shell
    shell=$(ps -p $$ -o comm= | sed 's/^-//')
    [ "$shell" = "sh" ] && {
        # Check for POSIX-compliant modes of different shells
        [ -n "$BASH_VERSION" ] && shell=bash
        [ -n "$ZSH_VERSION" ] && shell=zsh
        [ -n "$FISH_VERSION" ] && shell=fish
        [ -n "$NUSHELL_VERSION" ] && shell=nu 
    }
    echo "$shell"
}

# add_to_rc(shell, text, [skip_if])
#
# Adds text to the console's `rc` file if it doesn't already
# exist. Optionally the user may provide a "skip_if" value and
# if they do then the addition of text will also _not_ happen
# if that text is found.
function add_to_rc() {
    local -r shell="${1:?No shell passed to add_to_shell() function!}"
    local -r text="${2:?No text content passed to add_to_shell() function!}"
    local -r skip_if="${3:-}"

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



# isMacOrLinux()
#
# Returns `true` if current OS is macOS or Linux
function isMacOrLinux() {
    local -r os="$(os)";

    if [[ "${os}" == "linux" ]]; then
        return 0;
    elif [[ "${os}" == "macos" ]]; then
        return 0;
    else
        return 1;
    fi
}

function is_linux() {
    local -r os="$(os)";

    if [[ "${os}" == "linux" ]]; then
        return 0;
    else
        return 1;
    fi
}

# distro()
#
# will try to detect the distro and version of the os release
function distro() {
    if [[ $(os) == "linux" ]]; then
        # Check /etc/os-release
        if [ -f /etc/os-release ]; then
        local name version
        name=$(grep '^NAME=' /etc/os-release | cut -d= -f2- | sed 's/"//g')
        version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2- | sed 's/"//g')
        if [ -n "$name" ]; then
            if [ -n "$version" ]; then
            echo "$name/$version"
            else
            echo "$name/unknown"
            fi
            return
        fi
        fi

        # Check /etc/lsb-release
        if [ -f /etc/lsb-release ]; then
        local dist_id dist_release
        dist_id=$(grep '^DISTRIB_ID=' /etc/lsb-release | cut -d= -f2- | sed 's/"//g')
        dist_release=$(grep '^DISTRIB_RELEASE=' /etc/lsb-release | cut -d= -f2- | sed 's/"//g')
        if [ -n "$dist_id" ]; then
            if [ -n "$dist_release" ]; then
            echo "$dist_id/$dist_release"
            else
            echo "$dist_id/unknown"
            fi
            return
        fi
        fi

        # Check Debian
        if [ -f /etc/debian_version ]; then
        local version
        version=$(cat /etc/debian_version)
        echo "Debian/$version"
        return
        fi

        # Check Red Hat-based systems
        if [ -f /etc/redhat-release ]; then
        local content name version
        content=$(cat /etc/redhat-release)
        name=$(awk '{sub(/ release.*/, ""); print}' <<< "$content")
        version=$(awk '{for(i=1; i<=NF; i++) if ($i == "release") {print $(i+1); exit}}' <<< "$content")
        if [ -z "$version" ]; then
            version="unknown"
        fi
        echo "$name/$version"
        return
        fi

        # Check Alpine
        if [ -f /etc/alpine-release ]; then
        local version
        # shellcheck disable=SC2002
        version=$(cat /etc/alpine-release | tr -d '\n')
        echo "Alpine/$version"
        return
        fi

        # Check Arch Linux
        if [ -f /etc/arch-release ]; then
        echo "Arch Linux/unknown"
        return
        fi

        # Check Slackware
        if [ -f /etc/slackware-version ]; then
        local content name version
        content=$(cat /etc/slackware-version)
        name=$(awk '{print $1}' <<< "$content")
        version=$(awk '{print $2}' <<< "$content")
        echo "$name/$version"
        return
        fi

        # Check Gentoo
        if [ -f /etc/gentoo-release ]; then
        local version
        version=$(awk '{print $NF}' /etc/gentoo-release)
        echo "Gentoo/$version"
        return
        fi

        # Fallback if no known distro detected
        echo "unknown/unknown"
    else
        return 1
    fi
}

# os_version()
#
# Detect and return the OS version for Linux, macOS, and Windows
function os_version() {
    case $(os) in
        linux)
            local distro_output
            distro_output=$(distro)
            local version="${distro_output##*/}"
            
            # Handle Arch Linux's special case
            if [[ "$version" == "unknown" && "$distro_output" == *"Arch Linux/"* ]]; then
                if [ -f /etc/arch-release ]; then
                    version=$(date -r /etc/arch-release "+%Y.%m.%d")
                fi
            fi
            echo "$version"
            ;;
        macos)
            sw_vers -productVersion
            ;;
        windows)
            local ver_output version
            # Get Windows version from cmd.exe
            ver_output=$(cmd.exe /c ver 2>/dev/null)
            # shellcheck disable=SC2181
            if [[ $? -ne 0 ]]; then
                echo "unknown"
                return 1
            fi
            # Extract version from output format: "Microsoft Windows [Version 10.0.19045.4291]"
            version=$(echo "$ver_output" | awk '{print $4}' | tr -d ']')
            if [[ -z "$version" ]]; then
                echo "unknown"
                return 1
            fi
            echo "$version"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
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

# get_firmware()
#
# Gets the system firmware version
function get_firmware() {
    case $(os) in
        linux)
            if [ -f /sys/class/dmi/id/bios_version ]; then
                cat /sys/class/dmi/id/bios_version
            elif command -v dmidecode >/dev/null; then
                dmidecode -s bios-version 2>/dev/null || echo "unknown"
            else
                echo "unknown"
            fi
            ;;
        macos)
            system_profiler SPHardwareDataType | awk -F': ' '/Boot ROM Version/ {print $2}'
            ;;
        windows)
            cmd.exe /c "wmic bios get version" 2>/dev/null | awk 'NR==2 {print $1}' | tr -d '\r'
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# get_memory()
#
# Gets total physical memory in GB (rounded to 2 decimal places)
function get_memory() {
    case $(os) in
        linux)
            if [ -f /proc/meminfo ]; then
                awk '/MemTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo
            else
                echo "unknown"
            fi
            ;;
        macos)
            sysctl -n hw.memsize | awk '{printf "%.2f", $0/1024/1024/1024}'
            ;;
        windows)
            local -r mem_bytes=$(wmic ComputerSystem get TotalPhysicalMemory 2>/dev/null | awk 'NR==2 {print $1}')
            if [ -n "$mem_bytes" ]; then
                echo "$mem_bytes" | awk '{printf "%.2f", $0/1024/1024/1024}'
            else
                # Fallback to PowerShell command
                powershell.exe -Command "[math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)"
            fi
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

function is_debian() {
    if is_linux; then
        DISTRO="$(distro)"
        LC_DISTRO="$(lc "${DISTRO}")"
        if contains "debian" "${LC_DISTRO}"; then
            debug "is_debian" "is Debian OS [${LC_DISTRO}]"
            return 0
        else 
            debug "is_debian" "is NOT Debian OS [${LC_DISTRO}]"
            return 1
        fi 
    fi
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

# is_zsh()
#
# returns true/false based on whether the current shell is zsh.
function is_zsh() {
    local -r shell="$(get_shell)";

    if [[ "${shell}" == "zsh" ]]; then
        return 0;
    else
        return 1;
    fi
}

# is_bash()
#
# returns true/false based on whether the current shell is zsh.
function is_bash() {
    local -r shell="$(get_shell)";

    if [[ "${shell}" == "bash" ]]; then
        return 0;
    else
        return 1;
    fi
}

# is_fish()
#
# returns true/false based on whether the current shell is zsh.
function is_fish() {
    local -r shell="$(get_shell)";

    if [[ "${shell}" == "fish" ]]; then
        return 0;
    else
        return 1;
    fi
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


# link(text, uri)
#
# embeds a hyperlink into the console when using Wezterm
# and some other terminals (I think support is limited)
function link() {
    local -r text="${1:?no text passed to link() function}"
    local -r uri="${2:?no uri passed to link() function}"

    # shellcheck disable=SC2028
    echo "\e]8;;${uri}\e\\${text}\e]8;;\e\\"
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

