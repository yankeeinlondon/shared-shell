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

source "${UTILS}/text.sh"

# link <text> <uri>
#
# embeds a hyperlink into the console when using Wezterm
# and some other terminals (I think support is limited)
function link() {
    local -r text="${1:?no text passed to link() function}"
    local -r uri="${2:?no uri passed to link() function}"

    # Use BEL (\007) terminator which works better with printf %b
    # shellcheck disable=SC2028
    echo "\\033]8;;${uri}\\007${text}\\033]8;;\\007"
}


# link_file <text> <file>
#
# embeds a hyperlink into the console when using Wezterm
# and some other terminals (I think support is limited)
function link_file() {
    local -r text="${1:?no text passed to link() function}"
    local -r file="${2:?no uri passed to link() function}"

    local file_uri
    file_uri="$(ensure_starting "file://" "${file}" 2>/dev/null)"

    # Use BEL (\007) terminator which works better with printf %b
    # shellcheck disable=SC2028
    echo "\\033]8;;${file_uri}\\007${text}\\033]8;;\\007"
}

# link_repo <uri>
#
# Converts a URI referring to a repo into a clickable link in
# modern terminals. The URI format could be of either format:
# 1. `HTTP`: a format that looks like `https://github.com/ORG/REPO`
# 2. `git`: a format that looks like `git:github.com:ORG:REPO.git`
#
# The textual part of the link will simply proxy through the URI
# that was passed in but the link address must always be converted
# to an `https` based URL.
function link_repo() {
    local -r repo="${1:?no URI representing a Repo was passed to link_repo() function!}"
    local trimmed display uri host path converted

    trimmed="${repo}"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

    display="${trimmed}"

    if [[ "${trimmed}" == https://* ]]; then
        uri="${trimmed}"
    elif [[ "${trimmed}" == http://* ]]; then
        uri="https://${trimmed#http://}"
    elif [[ "${trimmed}" == git:* ]]; then
        converted="${trimmed#git:}"
        converted="${converted//:/\/}"
        uri="https://${converted%.git}"
    elif [[ "${trimmed}" == git@*:* ]]; then
        converted="${trimmed#*@}"
        host="${converted%%:*}"
        path="${converted#*:}"
        path="${path%.git}"
        uri="https://${host}/${path}"
    elif [[ "${trimmed}" == ssh://git@* ]]; then
        converted="${trimmed#ssh://git@}"
        host="${converted%%/*}"
        path="${converted#*/}"
        path="${path%.git}"
        uri="https://${host}/${path}"
    elif [[ "${trimmed}" == git+ssh://git@* ]]; then
        converted="${trimmed#git+ssh://git@}"
        host="${converted%%/*}"
        path="${converted#*/}"
        path="${path%.git}"
        uri="https://${host}/${path}"
    elif [[ "${trimmed}" == git://* ]]; then
        uri="https://${trimmed#git://}"
        uri="${uri%.git}"
    else
        uri="${trimmed}"
        if [[ "${uri}" != https://* ]]; then
            uri="https://${uri#https://}"
        fi
    fi

    uri="${uri%.git}"

    link "${display}" "${uri}"
}

# link_email <email>
#
# Converts an email address into a clickable link in a modern terminal.
# The URI format will be: `mailto://EMAIL_ADDRESS``
function link_email() {
    local -r email="${1:?no email passed to link_email() function!}"
    local trimmed display uri addr

    trimmed="${email}"
    trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    display="${trimmed}"

    if [[ "${trimmed}" == mailto:* ]]; then
        uri="${trimmed}"
        display="${trimmed#mailto:}"
    elif [[ "${trimmed}" == email://* ]]; then
        uri="mailto:${trimmed#email://}"
        display="${trimmed#email://}"
    else
        if [[ "${trimmed}" == *'<'*'>'* ]]; then
            addr="${trimmed##*<}"
            addr="${addr%%>*}"
            addr="${addr#"${addr%%[![:space:]]*}"}"
            addr="${addr%"${addr##*[![:space:]]}"}"
        else
            addr="${trimmed}"
        fi

        uri="mailto:${addr}"
    fi

    link "${display}" "${uri}"
}
