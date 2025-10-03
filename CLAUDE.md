# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of shared shell scripts that provide utilities for system configuration, environment setup, and shell enhancements across macOS and Linux (particularly Debian) systems. The scripts are designed to be sourced from `~/.config/sh/`.

## Core Architecture

### Script Dependencies

The scripts follow a hierarchical dependency structure:

- **color.sh**: Base color definitions - no dependencies
- **typeof.sh**: Type checking utilities - no dependencies
- **os.sh**: OS detection - imports color.sh
- **utils.sh**: Core utilities - imports color.sh, os.sh, typeof.sh
- **adaptive.sh**: Main entry point - orchestrates loading of other scripts based on detected environment and is intended to be _sourced_ from a user's `.bashrc`, `.zshrc`, etc.

### Key Modules

- **adaptive.sh**: Main initialization script that sources other modules and sets up completions
- **utils.sh**: Extensive utility functions for file operations, string manipulation, system detection
- **aliases.sh**: Dynamic alias generation based on available commands (kubectl, nvim, lazygit, eza/exa)
- **initialize.sh**: System initialization for Debian systems (package installation, tool setup)
- **proxmox.sh**: Proxmox VE API integration utilities
- **build.sh**: Source compilation scripts (e.g., neovim from source)

## Static Analysis

The repository includes powerful static analysis capabilities via `static.sh`:

```bash
# Analyze functions in a directory/file
./static.sh <path>

# Get JSON output of all functions (used by reports/fns.sh)
bash_functions_summary <path>
```

The static analysis extracts:
- Function names, arguments, descriptions from comment blocks
- File locations and line ranges
- Duplicate function detection

## Common Development Commands

```bash
# Source the adaptive configuration
source ~/.config/sh/adaptive.sh

# View all available utility functions
./reports/fns.sh

# Filter functions by glob pattern
./reports/fns.sh "is_*"        # functions starting with "is_"
./reports/fns.sh "*debug*"     # functions containing "debug"

# Test color utilities
./tests/color.sh

# Initialize a Debian system with standard tools
./initialize.sh
```

## Code Conventions

### Function Patterns

- Functions use lowercase with underscores: `function_name()`
- Local variables declared with `local -r` for readonly or `local` for mutable
- Error handling via `panic()` for fatal errors, `error()` for recoverable ones
- Debug output via `debug "function_name" "message"` pattern
- Return values: 0 for success/true, 1 for failure/false

### Function Documentation

Document functions with comment blocks immediately above the function definition:

```bash
# function_name <arg1> [optional_arg2]
#
# Description of what the function does.
# Can span multiple lines.
function function_name() {
    # implementation
}
```

The static analysis tool extracts:
- First line matching function name becomes the arguments specification
- Remaining lines become the description
- Empty line after first line is automatically stripped

### Variable Conventions

- Script directory references: `SCRIPT_DIR="${HOME}/.config/sh"`
- Color variables from color.sh: `${BOLD}`, `${RESET}`, `${RED}`, etc.
- Use `has_command` to check for command availability before use
- Use utility functions like `is_empty`, `not_empty`, `contains`, `starts_with` for string operations

### Shell Compatibility

- Scripts target bash but include compatibility checks for zsh/fish
- Only use bash syntax for Bash 3.x
- You should not assume the availability of tools outside of bash (e.g., ripgrep, etc.)
  - If you want to use these tools always create a function which abstracts the functionality and make sure that this function has a fallback or at least a graceful error message
- Use `get_shell()` to detect current shell
- Shell-specific operations wrapped in conditionals (`is_bash()`, `is_zsh()`, `is_fish()`)

### Color Utilities

The `utils/color.sh` module provides extensive RGB-based colorization:

- Use `setup_colors` to initialize standard ANSI color variables (`${RED}`, `${BOLD}`, etc.)
- Use `rgb_text "R G B" "text"` for custom RGB foreground colors
- Use `rgb_text "R G B / R2 G2 B2" "text"` for foreground + background
- Use `rgb_text "/ R G B" "text"` for background only
- Use `colorize` to convert `{{TAG}}` markers to color variables (e.g., `{{RED}}`, `{{BOLD}}`)
- Predefined color functions: `orange`, `tangerine`, `slate_blue`, `lime`, `pink`, etc.
- Each has variants: plain, `_backed` (dark text, colored bg), `_highlighted` (colored text + muted bg)
- Background-only functions: `bg_*` (e.g., `bg_light_blue`, `bg_dark_gray`)
- Use `remove_colors` to unset all color variables

### Testing

Run test scripts directly to see demonstrations:

```bash
./tests/color.sh    # Demonstrates color utilities with examples
```
