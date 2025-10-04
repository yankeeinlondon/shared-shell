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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"

# is_pve_host
#
# Returns an exit code which indicates whether the given machine is
# a PVE host or not.
function is_pve_host() {
    if has_command "pveversion"; then
        debug "is_pve_host" "is a pve node"
        return 0
    else
        debug "is_pve_host" "is NOT a pve node"
        return 1
    fi
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

# is_docker()
#
# Check for Docker container
is_docker() {
    # Check common Docker indicators
    if [ -f /.dockerenv ] ||
       { [ -f /proc/1/cgroup ] && grep -qi "docker\|kubepods" /proc/1/cgroup; }; then
        return 0
    fi
    return 1
}

# Check for LXC container
is_lxc() {
    # Check common LXC indicators
    if grep -q 'container=lxc' /proc/1/environ 2>/dev/null ||
       [ -f /run/.containerenv ] ||
       ( [ -f /proc/1/cgroup ] && grep -qi 'lxc' /proc/1/cgroup ); then
        return 0
    fi
    return 1
}

# Check for VM
is_vm() {
    # Check common VM indicators
    if grep -q 'hypervisor' /proc/cpuinfo 2>/dev/null ||
       ( [ -f /sys/class/dmi/id/product_name ] &&
         grep -qi -e 'qemu' -e 'kvm' /sys/class/dmi/id/product_name ); then
        return 0
    fi
    return 1
}

# using_bash_3
#
# tests whether the host OS has bash version 3 installed
function using_bash_3() {
    local -r version=$(bash_version)

    if starts_with "3" "${version}"; then
        debug "using_bash_3" "IS version 3 variant!"
        return 0
    else
        debug "using_bash_3" "is not version 3 variant"
        return 1
    fi
}

# bash_version()
#
# returns the version number of bash for the host OS
function bash_version() {
    local version
    version=$(bash --version)
    version=$(strip_after "(" "$version")
    version=$(strip_before "version " "$version")

    echo "$version"
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

# in_package_json <find>
#
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
