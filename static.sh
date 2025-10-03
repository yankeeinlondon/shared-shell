#!/usr/bin/env bash

# file_dependencies <file>
#
# provides the utility functions which a given file uses
function file_dependencies() {
    local -r file="${1:?no file passed to file_dependencies()!}"

    # TODO
}


# bash_functions_summary <location> <...>
#
# Takes the parameters passed to it as directories/files for which
# it should evaluate and perform static analysis to extract all of
# the functions it finds.
bash_functions_summary() {
    # Scan for bash functions in the directories provided via "$@"
    # Outputs a JSON object:
    # {
    #   "functions": [{
    #     "name": "...",
    #     "arguments": "...",
    #     "description": "...",
    #     "file": "...",
    #     "startBlock": N,
    #     "start": N,
    #     "end": M
    #   }, ...],
    #   "duplicates": ["...", "..."]
    # }

    if [ "$#" -eq 0 ]; then
        echo '{"functions":[],"duplicates":[]}'
        return 0
    fi

    # Build a list of candidate files:
    # - *.sh, *.bash
    # - files with NO dot in the basename (no extension)
    # We also prune common VCS/build dirs for speed.
    local -a __BFS_FILES=()
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        local base
        base=${path##*/}
        case "$base" in
        *.sh|*.bash)
            __BFS_FILES+=("$path")
            ;;
        *.*)
            ;; # ignore other extensions
        *)
            __BFS_FILES+=("$path")
            ;;
        esac
    done < <(
        find "$@" \
            -type d \( -name .git -o -name .hg -o -name .svn -o -name node_modules -o -name dist -o -name build -o -name .direnv -o -name .venv \) -prune -o \
            -type f -print 2>/dev/null
        )

    if [ "${#__BFS_FILES[@]}" -gt 1 ]; then
        local -a __BFS_UNIQUE=()
        while IFS= read -r path; do
        [ -z "$path" ] && continue
        __BFS_UNIQUE+=("$path")
        done < <(printf '%s\n' "${__BFS_FILES[@]}" | sort -u)
        __BFS_FILES=("${__BFS_UNIQUE[@]}")
    fi

    # If nothing to scan
    if [ "${#__BFS_FILES[@]}" -eq 0 ]; then
        echo '{"functions":[],"duplicates":[]}'
        return 0
    fi

    # shellcheck disable=SC2016

    # Use awk to parse each file and emit TSV rows:
    #   name \t file \t startBlock \t start \t end \t arguments \t description
    # The awk parser:
    # - Detects function headers:
    #     name() {        | function name() {        | function name {
    # - Counts { } braces to find the matching closing brace of the function body.
    # - Tries to ignore braces inside strings and # comments (best-effort).
    awk_parse_functions='
        # Count braces in a code line, ignoring those in single/double strings and trailing comments.
        function brace_delta(line,   i, c, in_s, in_d, esc, ch, delta, in_var) {
        # strip trailing comment not inside string or variable expansion
        # We do a lightweight pass to find first unescaped # not within quotes or ${}
        in_s = in_d = in_var = esc = 0
        for (i = 1; i <= length(line); i++) {
            ch = substr(line, i, 1)
            if (esc) { esc = 0; continue }
            if (ch == "\\") { esc = 1; continue }
            if (!in_d && ch == "'"'"'") { in_s = !in_s; continue }
            if (!in_s && ch == "\"") { in_d = !in_d; continue }
            # Track ${...} variable expansions
            if (!in_s && !in_d && ch == "$" && i < length(line) && substr(line, i+1, 1) == "{") {
                in_var++
                i++  # skip the {
                continue
            }
            if (in_var && ch == "{") { in_var++; continue }
            if (in_var && ch == "}") { in_var--; continue }
            if (!in_s && !in_d && !in_var && ch == "#") { line = substr(line, 1, i-1); break }
        }

        # remove contents of strings to avoid counting braces inside them
        gsub(/'"'"'([^'"'"'\\]|\\.)*'"'"'/, "'"'"''"'"'", line)
        gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
        # remove variable expansions to avoid counting braces inside them
        gsub(/\$\{[^}]*\}/, "$", line)
        gsub(/\$\(\([^)]*\)\)/, "$", line)  # $((...)) arithmetic
        gsub(/\$\([^)]*\)/, "$", line)  # $(...) command substitution

        # Now count braces
        delta = 0
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (c == "{") delta++
            else if (c == "}") delta--
        }
        return delta
        }

        # Detect function header and extract name; return 1 if matched, sets fnName.
        # BSD awk compatible - no capture groups
        function match_fn_header(line,   temp) {
        # name() {
        if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/)) {
            # Extract the function name manually
            temp = substr(line, RSTART, RLENGTH)
            gsub(/^[[:space:]]+/, "", temp)  # remove leading spaces
            gsub(/[[:space:]]*\(\).*$/, "", temp)  # remove () { and everything after
            fnName = temp
            return 1
        }
        # function name() {
        if (match(line, /^[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/)) {
            temp = substr(line, RSTART, RLENGTH)
            gsub(/^[[:space:]]*function[[:space:]]+/, "", temp)  # remove "function "
            gsub(/[[:space:]]*\(\).*$/, "", temp)  # remove () { and everything after
            fnName = temp
            return 1
        }
        # function name {
        if (match(line, /^[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\{/)) {
            temp = substr(line, RSTART, RLENGTH)
            gsub(/^[[:space:]]*function[[:space:]]+/, "", temp)  # remove "function "
            gsub(/[[:space:]]*\{.*$/, "", temp)  # remove { and everything after
            fnName = temp
            return 1
        }
        return 0
        }

        # Extract arguments from comment block if first line matches function name
        # Sets global: fn_args, fn_desc
        function extract_arguments(fname, comment,   first_line, rest, pattern, lines_array, n, i, skip_empty, start_idx, matched_char) {
        fn_args = ""
        fn_desc = comment

        if (comment == "") return

        # Split comment by \\n to get lines
        n = split(comment, lines_array, "\\\\n")
        if (n == 0) return

        first_line = lines_array[1]

        # Check if first line starts with function name
        # Pattern matches: fname, fname(), fname <args>, fname() <args>, fname(args)
        pattern = "^" fname "($|\\(\\)|[[:space:]]|\\()"
        if (match(first_line, pattern)) {
            # Extract arguments: everything after the matched portion
            rest = substr(first_line, RSTART + RLENGTH)

            # Check if we matched an opening parenthesis - if so, include it in rest
            matched_char = substr(first_line, RSTART + RLENGTH - 1, 1)
            if (matched_char == "(") {
            rest = "(" rest
            }

            # Trim whitespace
            gsub(/^[[:space:]]+/, "", rest)
            gsub(/[[:space:]]+$/, "", rest)
            fn_args = rest

            # Rebuild description without first line
            # Also skip second line if it is empty
            skip_empty = (n > 1 && lines_array[2] == "") ? 1 : 0
            start_idx = skip_empty ? 3 : 2

            fn_desc = ""
            for (i = start_idx; i <= n; i++) {
            if (fn_desc != "") fn_desc = fn_desc "\\\\n"
            fn_desc = fn_desc lines_array[i]
            }
        }
        }

        BEGIN {
        OFS = "\t"
        }

        FNR == 1 {
        file = FILENAME
        line_no = 0
        # Reset function tracking state for new file
        in_fn = 0
        depth = 0
        cur_name = ""
        start = 0
        # Reset comment tracking
        comment_block = ""
        comment_start = 0
        comment_count = 0
        }

        {
        line_no++
        line = $0

        # Check if this is a comment line (but not a shebang)
        if (match(line, /^[[:space:]]*#/) && !match(line, /^#!/)) {
            # Extract comment content (strip leading whitespace and #)
            comment_line = line
            gsub(/^[[:space:]]*#[[:space:]]*/, "", comment_line)

            # Start new comment block or continue existing one
            if (comment_count == 0) {
            comment_start = line_no
            comment_block = comment_line
            } else {
            # Append to existing block with newline separator
            comment_block = comment_block "\\n" comment_line
            }
            comment_count++
            next
        }

        # Skip shebang lines
        if (match(line, /^#!/)) {
            next
        }

        # Check if this is a blank line
        if (match(line, /^[[:space:]]*$/)) {
            # Clear comment block if not in a function (blank line separates comments from functions)
            if (!in_fn && comment_count > 0) {
                comment_block = ""
                comment_start = 0
                comment_count = 0
            }
            next
        }

        if (!in_fn && match_fn_header(line)) {
            # Found start of a function
            cur_name = fnName
            start = line_no
            start_block = (comment_count > 0) ? comment_start : line_no
            in_fn = 1
            depth = brace_delta(line)

            # Extract arguments from comment block
            extract_arguments(cur_name, comment_block)

            # If header line already closes (one-liner), find end here
            if (depth <= 0) {
            # Use placeholder for empty fields to prevent bash read issues
            args_out = (fn_args == "") ? "\x1F" : fn_args
            desc_out = (fn_desc == "") ? "\x1F" : fn_desc
            print cur_name, file, start_block, start, line_no, args_out, desc_out
            in_fn = 0
            comment_block = ""
            comment_start = 0
            comment_count = 0
            }
            next
        }

        # Clear comment block if we hit non-function code
        if (!in_fn && comment_count > 0) {
            comment_block = ""
            comment_start = 0
            comment_count = 0
        }

        if (in_fn) {
            depth += brace_delta(line)
            if (depth <= 0) {
            # Function ends on this line
            # Use placeholder for empty fields to prevent bash read issues
            args_out = (fn_args == "") ? "\x1F" : fn_args
            desc_out = (fn_desc == "") ? "\x1F" : fn_desc
            print cur_name, file, start_block, start, line_no, args_out, desc_out
            in_fn = 0
            comment_block = ""
            comment_start = 0
            comment_count = 0
            }
        }
        }
    '

    # Minimal JSON escape for strings: backslash and double quote, and newlines
    __bfs_json_escape() {
        local s=$1
        s=${s//\\/\\\\}
        s=${s//\"/\\\"}
        s=${s//$'\n'/\\n}
        s=${s//$'\r'/\\r}
        s=${s//$'\t'/\\t}
        printf '%s' "$s"
    }

    local functions_json="["
    local first=1
    local found=0
    local -a __BFS_NAMES=()

    while IFS=$'\t' read -r name file start_block start end arguments description; do
        found=1
        __BFS_NAMES+=("$name")

        # Replace placeholder with empty string
        [ "$arguments" = $'\x1F' ] && arguments=""
        [ "$description" = $'\x1F' ] && description=""

        if [ $first -eq 1 ]; then
        first=0
        else
        functions_json+=","
        fi

        esc_name=$(__bfs_json_escape "$name")
        esc_file=$(__bfs_json_escape "$file")
        esc_args=$(__bfs_json_escape "$arguments")
        esc_desc=$(__bfs_json_escape "$description")
        functions_json+=$(printf '{"name":"%s","arguments":"%s","description":"%s","file":"%s","startBlock":%d,"start":%d,"end":%d}' \
        "$esc_name" "$esc_args" "$esc_desc" "$esc_file" "$start_block" "$start" "$end")
    done < <(awk "$awk_parse_functions" "${__BFS_FILES[@]}" 2>/dev/null)

    if [ $found -eq 0 ]; then
        echo '{"functions":[],"duplicates":[]}'
        return 0
    fi

    functions_json+="]"

    local dups_json="["
    first=1
    if [ "${#__BFS_NAMES[@]}" -gt 0 ]; then
        local duplicates
        duplicates=$(printf '%s\n' "${__BFS_NAMES[@]}" | sort | uniq -d)
        while IFS= read -r dup; do
        [ -z "$dup" ] && continue
        if [ $first -eq 1 ]; then
            first=0
        else
            dups_json+=",";
        fi
        dups_json+=$(printf '"%s"' "$(__bfs_json_escape "$dup")")
        done <<<"$duplicates"
    fi
    dups_json+="]"

    printf '{"functions":%s,"duplicates":%s}\n' "$functions_json" "$dups_json"
}

# if run directly then proxy the parameter to the `bash_functions_summary`
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    bash_functions_summary "${@}"
fi
