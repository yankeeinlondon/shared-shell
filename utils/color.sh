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

# Source guard to prevent circular dependencies
[[ -n "${__COLOR_SH_LOADED:-}" ]] && return
__COLOR_SH_LOADED=1

# shellcheck source="./text.sh"
source "${UTILS}/text.sh"

function setup_colors() {
    export BLACK=$'\033[30m'
    export RED=$'\033[31m'
    export GREEN=$'\033[32m'
    export YELLOW=$'\033[33m'
    export BLUE=$'\033[34m'
    export MAGENTA=$'\033[35m'
    export CYAN=$'\033[36m'
    export WHITE=$'\033[37m'

    export BRIGHT_BLACK=$'\033[90m'
    export BRIGHT_RED=$'\033[91m'
    export BRIGHT_GREEN=$'\033[92m'
    export BRIGHT_YELLOW=$'\033[93m'
    export BRIGHT_BLUE=$'\033[94m'
    export BRIGHT_MAGENTA=$'\033[95m'
    export BRIGHT_CYAN=$'\033[96m'
    export BRIGHT_WHITE=$'\033[97m'

    export BOLD=$'\033[1m'
    export NO_BOLD=$'\033[21m'
    export DIM=$'\033[2m'
    export NO_DIM=$'\033[22m'
    export ITALIC=$'\033[3m'
    export NO_ITALIC=$'\033[23m'
    export STRIKE=$'\033[9m'
    export NO_STRIKE=$'\033[29m'
    export REVERSE=$'\033[7m'
    export NO_REVERSE=$'\033[27m'
    export UNDERLINE=$'\033[4m'
    export NO_UNDERLINE=$'\033[24m'
    export BLINK=$'\033[5m'
    export NO_BLINK=$'\033[25m'

    export BG_BLACK=$'\033[40m'
    export BG_RED=$'\033[41m'
    export BG_GREEN=$'\033[42m'
    export BG_YELLOW=$'\033[43m'
    export BG_BLUE=$'\033[44m'
    export BG_MAGENTA=$'\033[45m'
    export BG_CYAN=$'\033[46m'
    export BG_WHITE=$'\033[47m'

    export BG_BRIGHT_BLACK=$'\033[100m'
    export BG_BRIGHT_RED=$'\033[101m'
    export BG_BRIGHT_GREEN=$'\033[102m'
    export BG_BRIGHT_YELLOW=$'\033[103m'
    export BG_BRIGHT_BLUE=$'\033[104m'
    export BG_BRIGHT_MAGENTA=$'\033[105m'
    export BG_BRIGHT_CYAN=$'\033[106m'
    export BG_BRIGHT_WHITE=$'\033[107m'

    export RESET=$'\033[0m'

    export SAVE_POSITION=$'\033[s'
    export RESTORE_POSITION=$'\033[u'
    export CLEAR_SCREEN=$'\033[2J'
}

function screen_title() {
    local -r title=${1:?no title passed to screen_title()!}

    printf '\033]0;%s\007' "${title}"
}

function clear_screen() {
    printf '\033[2J'
}

function remove_colors() {
    unset RED BLACK GREEN YELLOW BLUE MAGENTA CYAN WHITE
    unset BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
    unset BOLD NO_BOLD DIM NO_DIM ITALIC NO_ITALIC STRIKE NO_STRIKE REVERSE NO_REVERSE
    unset UNDERLINE NO_UNDERLINE BLINK NO_BLINK
    unset BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
    unset BG_BRIGHT_BLACK BG_BRIGHT_RED BG_BRIGHT_GREEN BG_BRIGHT_YELLOW BG_BRIGHT_BLUE BG_BRIGHT_MAGENTA BG_BRIGHT_CYAN BG_BRIGHT_WHITE
    unset RESET
    unset SAVE_POSITION RESTORE_POSITION
}

# as_rgb_prefix <fg> <bg>
#
# Receives a string for both the foreground and background colors desired
# and after trimming these strings to eliminated unwanted whitespace it
# constructs the overall escape code that will be necessary to produce
# this.
function as_rgb_prefix() {
    local -r fg="$(trim "${1:-}")"
    local -r bg="$(trim "${2:-}")"
    local result=""


    # Build foreground escape code if provided
    if [[ -n "$fg" ]]; then
        # Parse RGB values (expecting "r g b" format)
        # shellcheck disable=SC2206
        local -ra fg_values=($fg)
        if [[ ${#fg_values[@]} -eq 3 ]] &&
           [[ "${fg_values[0]}" =~ ^[0-9]+$ ]] &&
           [[ "${fg_values[1]}" =~ ^[0-9]+$ ]] &&
           [[ "${fg_values[2]}" =~ ^[0-9]+$ ]]; then
            result+=$'\033[38;2;'${fg_values[0]}';'${fg_values[1]}';'${fg_values[2]}'m'
        fi
    fi

    # Build background escape code if provided
    if [[ -n "$bg" ]]; then
        # Parse RGB values (expecting "r g b" format)
        # shellcheck disable=SC2206
        local -ra bg_values=($bg)
        if [[ ${#bg_values[@]} -eq 3 ]] &&
           [[ "${bg_values[0]}" =~ ^[0-9]+$ ]] &&
           [[ "${bg_values[1]}" =~ ^[0-9]+$ ]] &&
           [[ "${bg_values[2]}" =~ ^[0-9]+$ ]]; then
            result+=$'\033[48;2;'${bg_values[0]}';'${bg_values[1]}';'${bg_values[2]}'m'
        fi
    fi

    printf '%s' "$result"
}



# rgb_text <color> <text>
#
# A RGB color value is passed in first:
#    - use a space delimited rgb value (e.g., 255 100 0)
#    - if you express just a single RGB value than that will be used
#    as the foreground/text color
#    - if you want to specify both foreground and background then you
#     will include two RGB values delimited by a `/` character (e.g.,
#      `255 100 0 / 30 30 30` )
#    - if you ONLY want to set the background then just use the `/` character
#      followed by an RGB value (e.g., `/ 30 30 30`)
#
# The second parameter is the text you want to render with this RGB definition.
rgb_text() {
    local -r color=${1:?RGB color value must be passed as first parameter to rgb_text()!}
    local -r text="${2:-}"
    local -r terminal=$'\033[0m'

    local fg_color=""
    local bg_color=""

    if [[ "$color" == *"/"* ]]; then
        # Contains both foreground and background or just background
        fg_color="$(trim "$(strip_after "/" "${color}")")"
        bg_color="$(trim "$(strip_before "/" "${color}")")"
        # If fg_color equals the original color, there was only background
        if [[ "$fg_color" == "$color" ]]; then
            fg_color=""
        fi
    elif [[ "$color" == "/"* ]]; then
        # Only background
        bg_color="${color#/ }"
    else
        # Only foreground
        fg_color="$color"
    fi

    printf '%s%s%s' "$(as_rgb_prefix "${fg_color}" "${bg_color}")" "${text}" "${terminal}"
}

# orange <orange-text> <rest-text>
#
# produces orange text using RGB values for the content
# in "${1}" and then just plain text for whatever (if anything)
# is in "${2}".
function orange() {
    local -r text="$(rgb_text "242 81 29" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# orange_highlighted <colorized-text> <rest-text>
function orange_highlighted() {
    local -r text="$(rgb_text "242 81 29/71 49 55" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# orange_backed <colorized-text> <rest-text>
function orange_backed() {
    local -r text="$(rgb_text "16 16 16/242 81 29" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# blue <colorized-text> <rest-text>
function blue() {
    local -r text="$(rgb_text "4 51 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# blue_backed <colorized-text> <rest-text>
function blue_backed() {
    local -r text="$(rgb_text "235 235 235/4 51 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}
# light_blue_backed <colorized-text> <rest-text>
function light_blue_backed() {
    local -r text="$(rgb_text "8 8 8/65 128 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_blue_backed <colorized-text> <rest-text>
function dark_blue_backed() {
    local -r text="$(rgb_text "235 235 235/1 25 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine <colorized-text> <rest-text>
function tangerine() {
    local -r text="$(rgb_text "255 147 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine_highlighted <colorized-text> <rest-text>
function tangerine_highlighted {
    local -r text="$(rgb_text "255 147 0 / 125 77 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine_backed <colorized-text> <rest-text>
function tangerine_backed {
    local -r text="$(rgb_text "16 16 16 / 255 147 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# slate_blue <colorized-text> <rest-text>
#
# produces slate blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function slate_blue() {
    local -r text="$(rgb_text "63 99 139" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# slate_blue_backed <slate_blue_backed-text> <rest-text>
#
# produces slate blue text with a light background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function slate_blue_backed() {
    local -r text="$(rgb_text "63 99 139/203 237 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# green <colorized-text> <rest-text>
function green() {
    local -r text="$(rgb_text "0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# green_backed <colorized-text> <rest-text>
function green_backed() {
    local -r text="$(rgb_text "8 8 8/0 229 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_green_backed <colorized-text> <rest-text>
function light_green_backed() {
    local -r text="$(rgb_text "8 8 8/0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# dark_green_backed <colorized-text> <rest-text>
function dark_green_backed() {
    local -r text="$(rgb_text "235 235 235/0 65 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# lime <colorized-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function lime() {
    local -r text="$(rgb_text "15 250 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# blue_backed <colorized-text> <rest-text>
#
# produces blue text with a lighter background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function lime_backed() {
    local -r text="$(rgb_text "33 33 33/15 250 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# pink <colorized-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function pink() {
    local -r text="$(rgb_text "255 138 216" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# pink_backed <colorized-text> <rest-text>
#
# produces text with a pink background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function pink_backed() {
    local -r text="$(rgb_text "33 33 33/255 138 216" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_pink_backed <colorized-text> <rest-text>
#
# produces text with a pink background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function dark_pink_backed() {
    local -r text="$(rgb_text "235 235 235/148 23 81" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}




# yellow <colored-text> <rest-text>
#
# produces dark red text with a lighter background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is in "${2}".
function yellow() {
    local -r text="$(rgb_text "255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_yellow_backed <colored-text> <rest-text>
function light_yellow_backed() {
    local -r text="$(rgb_text "8 8 8/255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# yellow_backed <colored-text> <rest-text>
function yellow_backed() {
    local -r text="$(rgb_text "8 8 8/255 251 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# dark_yellow_backed <colored-text> <rest-text>
function dark_yellow_backed() {
    local -r text="$(rgb_text "255 255 255/146 144 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# red <colored-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function red() {
    local -r text="$(rgb_text "255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# red_backed <colored-text> <rest-text>
function red_backed() {
    local -r text="$(rgb_text "235 235 235/255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}



# dark_red_backed <colored-text> <rest-text>
function dark_red_backed() {
    local -r text="$(rgb_text "235 235 235/148 17 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# light_red_backed <colored-text> <rest-text>
function light_red_backed() {
    local -r text="$(rgb_text "8 8 8/255 126 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# purple <colored-text> <rest-text>
#
# produces purple text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function purple() {
    local -r text="$(rgb_text "172 57 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# purple_backed <colored-text> <rest-text>
function purple_backed() {
    local -r text="$(rgb_text "235 235 235/148 55 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_purple_backed <colored-text> <rest-text>
function light_purple_backed() {
    local -r text="$(rgb_text "8 8 8/215 131 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_purple_backed <colored-text> <rest-text>
function dark_purple_backed() {
    local -r text="$(rgb_text "235 235 235/83 27 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function black_backed() {
    local -r text="$(rgb_text "192 192 192/0 0 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function white_backed() {
    local -r text="$(rgb_text "66 66 66/255 255 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function gray_backed() {
    local -r text="$(rgb_text "33 33 33/169 169 169" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function light_gray_backed() {
    local -r text="$(rgb_text "55 55 55/214 214 214" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function dark_gray_backed() {
    local -r text="$(rgb_text "235 235 235/66 66 66" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


function bg_gray() {
    local -r text="$(rgb_text "/94 94 94" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_gray() {
    local -r text="$(rgb_text "/146 146 146" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_gray() {
    local -r text="$(rgb_text "/66 66 66" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}



function bg_blue() {
    local -r text="$(rgb_text "/0 84 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_blue() {
    local -r text="$(rgb_text "/0 150 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_blue() {
    local -r text="$(rgb_text "/1 25 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_green() {
    local -r text="$(rgb_text "/0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_green() {
    local -r text="$(rgb_text "/0 172 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_green() {
    local -r text="$(rgb_text "/0 114 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_yellow() {
    local -r text="$(rgb_text "/255 251 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_yellow() {
    local -r text="$(rgb_text "/255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_yellow() {
    local -r text="$(rgb_text "/146 144 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_red() {
    local -r text="$(rgb_text "/255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_red() {
    local -r text="$(rgb_text "/255 126 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_red() {
    local -r text="$(rgb_text "/148 17 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# colorize <content>
#
# Looks for tags which represent formatting instructions -- `{{RED}}`, `{{RESET}}`,
# etc. -- and converts them using a variable of the same name.
colorize() {
    local -r content="${1:-}"
    local rest="$content"
    local result=""
    local tag

    while [[ "$rest" == *"{{"* ]]; do
        result+="${rest%%\{\{*}"
        rest="${rest#*\{\{}"

        if [[ "$rest" != *"}}"* ]]; then
            result+="{{${rest}"
            rest=""
            break
        fi

        tag="${rest%%\}\}*}"
        rest="${rest#*\}\}}"

        if [[ ${!tag+x} ]]; then
            result+="${!tag}"
        else
            result+="{{${tag}}}"
        fi
    done

    result+="$rest"

    printf '%s' "$result"
}


