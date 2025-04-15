DOT_RED=$(tput setaf 1)
DOT_GREEN=$(tput setaf 2)
DOT_YELLOW=$(tput setaf 3)
DOT_BOLD=$(tput bold)
DOT_RESET=$(tput sgr0)

function print_bold() {
    local message="$*"
    printf "%s\n" "${DOT_BOLD}${message}${DOT_RESET}"
}

function print_red() {
    local message="$*"
    printf "%s\n" "${DOT_BOLD}${DOT_RED}${message}${DOT_RESET}"
}

function print_yellow() {
    local message="$*"
    printf "%s\n" "${DOT_BOLD}${DOT_YELLOW}${message}${DOT_RESET}"
}

function print_green() {
    local message="$*"
    printf "%s\n" "${DOT_BOLD}${DOT_GREEN}${message}${DOT_RESET}"
}

function is_bash() {
    # using $BASH_VERSION
    if [ -n "$BASH_VERSION" ]; then
        return 0
    fi
    return 1
}

function is_zsh() {
    # using $ZSH_VERSION
    if [ -n "$ZSH_VERSION" ]; then
        return 0
    fi
    return 1
}
