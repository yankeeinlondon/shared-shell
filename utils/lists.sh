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

source "${UTILS}/logging.sh"

# retain_prefixes_val <prefix1> <...prefixes>
#
# Iterates over values from stdin and returns only
# those items which _start with_ one of the prefixes
# provided.
retain_prefixes_val() {
  local prefixes=("$@")
  local item matched=0
  local out=()

  while IFS= read -r item; do
    matched=0
    for p in "${prefixes[@]}"; do
      if [[ $item == ${p}* ]]; then
        matched=1
        break
      fi
    done
    (( matched )) && out+=("$item")
  done

  printf '%s\n' "${out[@]}"
}


# retain_prefixes_ref <variable_ref> <prefix1> <...prefixes>
#
# Iterates over the items in the `variable_ref` array
# and returns only those items which _start with_ one
# of the prefixes provided.
retain_prefixes_ref() {
  local -n _arr="$1"; shift
  local it p match
  for it in "${_arr[@]}"; do
    match=0
    for p in "$@"; do
      [[ $it == ${p}* ]] && match=1 && break
    done
    (( match )) && printf '%s\n' "$it"
  done
}


# filter_prefixes_val <prefix1> <...prefixes>
#
# Filters out items from stdin which start with any
# of the string prefixes provided.
filter_prefixes_val() {
  local prefixes=("$@")
  local item matched=0
  local out=()

  while IFS= read -r item; do
    matched=0
    for p in "${prefixes[@]}"; do
      if [[ $item == ${p}* ]]; then
        matched=1
        break
      fi
    done
    (( ! matched )) && out+=("$item")
  done

  printf '%s\n' "${out[@]}"
}


# filter_prefixes_ref <variable_ref> <prefix1> <...prefixes>
#
# Filters out the items in the `variable_ref` list
# which start with any of the string prefixes provided.
filter_prefixes_ref() {
  local -n _arr="$1"; shift
  local it p match
  for it in "${_arr[@]}"; do
    match=0
    for p in "$@"; do
      [[ $it == ${p}* ]] && match=1 && break
    done
    (( ! match )) && printf '%s\n' "$it"
  done
}


# list_contains_ref <variable_ref> <search_value>
#
# Checks if the array referenced by `variable_ref` contains
# the `search_value`. Returns 0 if found, 1 if not found.
list_contains_ref() {
    local -n _arr="$1"
    local -r find="$2"
    local it

    for it in "${_arr[@]}"; do
        [[ "$it" == "$find" ]] && return 0
    done
    return 1
}

# list_contains_val <search_value>
#
# Checks if the list of items from stdin contains the
# `search_value`. Returns 0 if found, 1 if not found.
list_contains_val() {
    local -r find="$1"
    local item

    while IFS= read -r item; do
        [[ "$item" == "$find" ]] && return 0
    done
    return 1
}
