#!/usr/bin/env bash

# shellcheck disable=SC2155
__adaptive_resolve_root() {
    if [[ -n ${BASH_SOURCE[0]:-} ]]; then
        builtin cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd
        return
    fi

    if [[ -n ${ZSH_VERSION:-} ]]; then
        local sourced
        eval 'sourced="${(%):-%x}"'
        builtin cd "$(dirname "${sourced}")" 2>/dev/null && pwd
        return
    fi

    pwd
}

export ADAPTIVE_SHELL="$(__adaptive_resolve_root)"
unset -f __adaptive_resolve_root

ROOT="${ADAPTIVE_SHELL}"
UTILS="${ROOT}/utils"
REPORTS="${ROOT}/reports"

function login_message() {
    source "${UTILS}/color.sh"
    setup_colors
    log ""
    log "${DIM}* use the ${BOLD:-}${GREEN:-}about${RESET:-} ${ITALIC}function${RESET} to get details on this machine${RESET}"

    remove_colors
}

# Get the directory of the current script
CONFIG_LOCATION="${HOME}/.config/sh"
COMPLETIONS="${HOME}/.completions"


# shellcheck source="./utils/text.sh"
source "${ROOT}/utils.sh"

# shellcheck source="./reports/paths.sh"
source "${REPORTS}/paths.sh"
# shellcheck source="./reports/aliases.sh"
source "${REPORTS}/aliases.sh"

# Set up aliases and PATH variables
set_aliases

if is_zsh; then
    emulate zsh -R
fi

if has_command "rustup"; then
    # Skip completion setup in non-interactive shells
    if [[ "$-" == *i* ]]; then
        RUSTUP=$(add_completion "rustup" "$(rustup completions "$(get_shell)" rustup 2>/dev/null || echo)" 2>/dev/null || true)
        CARGO=$(add_completion "cargo" "$(rustup completions "$(get_shell)" cargo 2>/dev/null || echo)" 2>/dev/null || true)
        if ! is_zsh; then
            if not_empty "${RUSTUP}" && [ -f "${RUSTUP}" ]; then
                # shellcheck disable=SC1090
                source "${RUSTUP}" 2>/dev/null || true
            fi
            if not_empty "${CARGO}" && [ -f "${CARGO}" ]; then
                # shellcheck disable=SC1090
                source "${CARGO}" 2>/dev/null || true
            fi
        fi
    fi
fi

if type uv &>/dev/null; then
    if is_fish; then
        uv generate-shell-completion fish
    else
        # Skip completion setup in non-interactive shells
        if [[ "$-" == *i* ]]; then
            UV=$(add_completion "uv" "$(rustup completions "$(get_shell)" rustup 2>/dev/null || echo)" 2>/dev/null || true)
            # shellcheck disable=SC1090
            ([ -n "$UV" ] && [ -f "$UV" ] && source "$UV" 2>/dev/null) || true
        fi
    fi
fi

if has_command "pyenv"; then
    add_to_rc "PYENV_ROOT=${HOME}/.pyenv"
    if dir_exists "${HOME}/.pyenv/bin"; then
        add_to_path "${HOME}/.pyenv/bin"
    fi
    if ! file_exists "${COMPLETIONS}/_pyenv"; then
        echo "- adding $(get_shell) completions for pyenv to ${BLUE}${COMPLETIONS}${RESET} directory"
        echo ""
        pyenv init - "$(get_shell)" >> "${COMPLETIONS}/_pyenv"
    fi
    # if file_exists "${COMPLETIONS}/_pyenv.zsh"; then
    #     if if_zsh; then
    #         source "${COMPLETIONS}/_pyenv.zsh"
    #     fi
    # else
    #     echo "- ${BOLD}warning:${RESET} expected a completions file at: ${BLUE}${COMPLETIONS}/_pyenv${RESET}"
    #     echo "  but not found!"
    # fi
fi

if type pm2 &>/dev/null; then
    # shellcheck source="./resources/_pm2"
    source "${CONFIG_LOCATION}/resources/_pm2"
fi

if is_mac; then
    function flush() {
        if confirm "Flush DNS Cache?"; then
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
        fi
    }
fi

if type brew &>/dev/null; then
    HOMEBREW_PREFIX=$(brew --prefix)
    if is_zsh; then
        fpath+=( "$HOMEBREW_PREFIX/share/zsh/site-functions" )
    elif is_bash; then
        if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
                # shellcheck disable=SC1091
                source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
            for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
                # shellcheck disable=SC1090
                [[ -r "$COMPLETION" ]] && source "${COMPLETION}"
            done
        fi
    fi
fi

if is_zsh; then
    if file_exists "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    unsetopt beep

    fpath+=( "${HOME}/.completions" )
    autoload -Uz compinit && compinit
    autoload -U add-zsh-hook
fi

if is_pve_host; then
    # shellcheck source="./utils/proxmox.sh"
    source "${UTILS}/proxmox.sh"
fi

if type aws_completer &>/dev/null; then
    if ! is_zsh; then
        # Skip completion setup in non-interactive shells
        if [[ "$-" == *i* ]]; then
            # shellcheck disable=SC1090
            source <"$(aws_completer "$(get_shell)" 2>/dev/null || echo)" 2>/dev/null || true
        fi
    fi
fi

if ! file_exists "${HOME}/.adaptive-initialized"; then
    OS="$(os)"
    distro="$(distro)"

    log ""
    log "It appears this system hasn't yet been initialized for your OS."
    log "Initialization just ensures that the core utils for your OS are"
    log "installed as a baseline."
    log ""
    if is_linux; then
        log "The detected OS is: ${BOLD}${BRIGHT_BLUE}${OS}${RESET} → ${BOLD}${distro}${RESET}"
    else
        log "The detected OS is: ${BOLD}${BRIGHT_BLUE}${OS}${RESET}"
    fi
    log ""
    if confirm "Would you like to do this now?"; then

        log "Installing"
        touch "${HOME}/.adaptive-initialized"

        bash "${HOME}/.config/sh/initialize.sh"
    else
        log "Ok bye."
        log "${DIM}- run ${BOLD}${BLUE}initialize${RESET}${DIM} at any time to "

        touch "${HOME}/.adaptive-initialized"
    fi

fi


if not_empty "${WEZTERM_CONFIG_DIR}"; then
  if file_exists "${UTILS}/wezterm.sh"; then
    # shellcheck source="./utils/wezterm.sh"
    source "${UTILS}/wezterm.sh"
  fi
fi

# source user's `.env` in home directory
# if it exists.
if file_exists "${HOME}/.env"; then
    set -a
    # shellcheck disable=SC1091
    source "${HOME}/.env"
    set +a
fi


if has_command "gpg"; then
    TTY="$(tty)"
    export GPG_TTY="$TTY"
fi

if [ -z "${LANG}" ]; then
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi

source "${ROOT}/user-functions.sh"

if type "starship" &>/dev/null; then
    if is_zsh; then
        eval "$(starship init zsh)"
    elif is_bash; then
        eval "$(starship init bash)"
    fi
fi

if type "atuin" &>/dev/null; then
    SHELL="$(get_shell)";
    eval "$(atuin init "${SHELL}" --disable-up-arrow)"
fi

if type "direnv" &>/dev/null; then
    SHELL="$(get_shell)";
    eval "$(direnv hook "${SHELL}")"
fi

login_message
