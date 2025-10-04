#!/usr/bin/env bash

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


# is_empty_string() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty_string() {

    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "is_empty(${1})" "was empty, returning 0/true"
        return 0
    else
        debug "is_empty(${1}))" "was NOT empty, returning 1/false"
        return 1
    fi
}


# is_empty() <test | ref:test>
#
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
#
# Simplified version that works without typeof/errors dependencies
function is_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        return 0
    else
        return 1
    fi
}
