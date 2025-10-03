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
# shellcheck source="./logging.sh"
source "${UTILS}/empty.sh"


# lc <string>
#
# converts the passed in <string> to lowercase
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
        error "contains("", ${content}) function did not receive a FIND string! This is an invalid call!" 1
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

# strip_before <find> <content>
#
# Retains all the characters after the first instance of <find> is
# found.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "world:of:tomorrow"
function strip_before() {
    local -r find="${1:?strip_before() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    echo "${content#*"${find}"}"
}


# strip_before_last <find> <content>
#
# Retains all the characters after the last instance of <find> is
# found.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "tomorrow"
function strip_before_last() {
    local -r find="${1:?strip_before_last() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    echo "${content##*"${find}"}"

}


# strip_after <find> <content>
#
# Strips all characters after finding <find> in content inclusive
# of the <find> text.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "hello"
function strip_after() {
    local -r find="${1:?strip_after() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    if not_empty "content"; then
        echo "${content%%"${find}"*}"
    else
        echo ""
    fi
}

# strip_after_last <find> <content>
#
# Strips all characters after finding the FINAL <find> substring
# in the content.
#
# Ex: strip_after_last ":" "hello:world:of:tomorrow" → "hello:world:of"
function strip_after_last() {
    local -r find="${1:?strip_after_last() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    if not_empty "content"; then
        echo "${content%"${find}"*}"
    else
        echo ""
    fi
}



# ensure_starting <ensure> <content>
#
# ensures that the "content" will start with the <ensure>
function ensure_starting() {
    local -r ensured="${1:?No ensured string provided to ensure_starting}"
    local -r content="${2:?-}"

    if starts_with "${ensured}" "$content"; then
        debug "ensure_starting" "the ensured text '${ensured}' was already in place"
        echo "${content}"
    else
        debug "ensure_starting" "the ensured text '${ensured}' was added in front of '${content}'"

        echo "${ensured}${content}"
    fi

    return 0
}

# has_characters <chars> <content>
#
# tests whether the content has any of the characters passed in
function has_characters() {
    local -r char_str="${1:?has_characters() did not receive a CHARS string!}"
    local -r content="${2:?content expression not passed to has_characters()}"
    # shellcheck disable=SC2207
    # local -ra chars=( $(echo "${char_str}" | grep -o .) )
    # local found="false"

    if [[ "$content" == *["$char_str"]* ]]; then
        debug "has_characters" "does have some of these characters: '${char_str}'"
        return 0
    else
        debug "has_characters" "does NOT have any of these characters: '${char_str}'"
        return 1
    fi
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
find_replace() {
  local find="$1"
  local replace="$2"
  local content="$3"

  # Test whether the "find" argument is in the regex form: /pattern/modifiers
  if printf "%s" "$find" | grep -qE '^/.*/[a-zA-Z]*$'; then
    local pattern modifiers
    pattern=$(printf "%s" "$find" | sed -E 's|^/(.*)/([a-zA-Z]*)$|\1|')
    modifiers=$(printf "%s" "$find" | sed -E 's|^/(.*)/([a-zA-Z]*)$|\2|')

    # Pass the replacement string in the REPL environment variable.
    # This prevents any shell-quoting issues from stripping or mangling ANSI codes.
    REPL="$replace" \
      printf "%s" "$content" | perl -pe 's/'"$pattern"'/$ENV{REPL}/'"$modifiers"
  else
    # For literal string replacement, use Bash's built-in substitution.
    printf "%s" "${content//$find/$replace}"
  fi
}


# indent(indent_txt, main_content)
function indent() {
    local -r indent_txt="${1:?No indentation text passed to indent()!}"
    local -r main_content="${2:?No main content passed to indent()!}"

    printf "%s\n" "$main_content" | while IFS= read -r line; do
        printf "%s%s\n" "${indent_txt}" "${line}"
    done
}


# newline_on_word_boundary <content> <length>
#
# Splits the content onto a new line when the character length
# reaches <length> but doesn't split until a word boundary is found.
# Preserves escape codes like ${DIM}, ${ITALIC}, ${RESET}, etc.
function newline_on_word_boundary() {
    local -r content="${1:?-}"
    local -r len="${2:?no length was passed to newline_on_word_boundary()!}"

    # Validate length parameter
    if ! [[ "$len" =~ ^[0-9]+$ ]] || [[ "$len" -le 0 ]]; then
        error "newline_on_word_boundary()" "length must be a positive number, received: $len" 2
        return 2
    fi

    # Handle empty content
    if [[ -z "$content" ]]; then
        debug "newline_on_word_boundary()" "received empty content"
        echo ""
        return 0
    fi

    # Function to strip escape codes for length calculation
    strip_escape_codes() {
        local text="$1"
        # Remove ANSI escape sequences
        echo "$text" | sed 's/\x1b\[[0-9;]*m//g'
    }

    # Get clean version (without escape codes) for length calculation
    local clean_content
    clean_content="$(strip_escape_codes "$content")"

    # First, split the clean content into lines of max length
    local clean_lines=""
    local current_clean_line=""
    local -i current_length=0

    # Split clean content into words
    local -a clean_words
    read -ra clean_words <<< "$clean_content"

    for clean_word in "${clean_words[@]}"; do
        local -i word_length=${#clean_word}

        # Calculate potential length
        local -i potential_length=$current_length
        if [[ $current_length -gt 0 ]]; then
            potential_length=$((current_length + word_length + 1))
        else
            potential_length=$word_length
        fi

        # Check if word fits
        if [[ $potential_length -gt $len && $current_length -gt 0 ]]; then
            # Word doesn't fit, start new line
            clean_lines="${clean_lines}${current_clean_line}"$'\n'
            current_clean_line="$clean_word"
            current_length=$word_length
        else
            # Word fits, add to current line
            if [[ $current_length -gt 0 ]]; then
                current_clean_line="${current_clean_line} ${clean_word}"
                current_length=$((current_length + word_length + 1))
            else
                current_clean_line="$clean_word"
                current_length=$word_length
            fi
        fi
    done

    # Add the last line
    if [[ $current_length -gt 0 ]]; then
        clean_lines="${clean_lines}${current_clean_line}"
    fi

    # Now, map the clean lines back to the original content with escape codes
    local result=""
    local original_pos=0

    # Process each clean line
    while IFS= read -r clean_line; do
        local -i clean_line_length=${#clean_line}
        local original_line=""
        local -i chars_to_copy=$clean_line_length

        # Copy characters from original content, preserving escape codes
        while [[ $chars_to_copy -gt 0 && $original_pos -lt ${#content} ]]; do
            local char="${content:$original_pos:1}"

            # Check if this is the start of an ANSI escape sequence
            if [[ "$char" == $'\x1b' && $((original_pos+1)) -lt ${#content} && "${content:$((original_pos+1)):1}" == '[' ]]; then
                # Find the end of the ANSI escape sequence
                local escape_end_pos=$((original_pos+2))
                while [[ $escape_end_pos -lt ${#content} && "${content:$escape_end_pos:1}" != 'm' ]]; do
                    escape_end_pos=$((escape_end_pos + 1))
                done
                if [[ $escape_end_pos -lt ${#content} && "${content:$escape_end_pos:1}" == 'm' ]]; then
                    escape_end_pos=$((escape_end_pos + 1)) # Include the 'm'
                fi

                # Add the complete escape sequence to the line
                original_line="${original_line}${content:$original_pos:$((escape_end_pos - original_pos))}"
                original_pos=$escape_end_pos
            else
                # Regular character - check if it matches the expected clean character
                local expected_char="${clean_line:$((clean_line_length - chars_to_copy)):1}"

                if [[ "$char" == "$expected_char" ]]; then
                    # Character matches, add it and move both positions
                    original_line="${original_line}${char}"
                    original_pos=$((original_pos + 1))
                    chars_to_copy=$((chars_to_copy - 1))
                else
                    # Character doesn't match (likely due to escape codes in original)
                    # Skip this character in original and try the next one
                    original_pos=$((original_pos + 1))
                fi
            fi
        done

        # Add the line to result
        if [[ -n "$result" ]]; then
            result="${result}"$'\n'
        fi
        result="${result}${original_line}"

        # Skip space in original content if there is one
        if [[ $original_pos -lt ${#content} && "${content:$original_pos:1}" == ' ' ]]; then
            original_pos=$((original_pos + 1))
        fi
    done <<< "$clean_lines"

    debug "newline_on_word_boundary()" "split content to max length $len"
    echo "$result"
    return 0
}

# trim_val <value>
#
# Take the content passed to it and then trims all leading and
# trailing whitespace. The trimmed value is returned.
function trim_val() {
  # Usage: trim "   some text   "
  local input="$*"
  # Remove leading and trailing whitespace using parameter expansion
  # (requires Bash 4+)
  input="${input#"${input%%[![:space:]]*}"}"   # remove leading
  input="${input%"${input##*[![:space:]]}"}"   # remove trailing
  echo "$input"
}

# trim_ref <ref>
#
# Take a reference to a variable and changes the variable to
# a string with all leading and trailing whitespace removed.
trim_ref() {
  # Usage: trim_ref var_name
  local var_name="$1"
  local value="${!var_name}"

  # Remove leading whitespace
  value="${value#"${value%%[![:space:]]*}"}"
  # Remove trailing whitespace
  value="${value%"${value##*[![:space:]]}"}"

  # Reassign the trimmed value to the original variable
  printf -v "$var_name" '%s' "$value"
}

# trim <ref_or_value>
#
# Takes either a reference to a variable _or_ textual content as a
# parameter. It then leverages the `trim_ref()` or `trim_val()` functions
# based on the type of parameters you pass it.
trim() {
  # Usage:
  #   trim "  some text  "     → echoes trimmed text
  #   trim var_name             → trims var in-place

  local arg="$1"

  if [[ $# -eq 1 && $arg =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ && ${!arg+_} ]]; then
    # 🧭 Case 1: variable name (in-place)
    local value="${!arg}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf -v "$arg" '%s' "$value"
  else
    # 🧭 Case 2: direct string (echo result)
    local value="$*"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
  fi
}
