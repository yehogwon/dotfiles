RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

function print() {
    local message="$*"
    printf "%s\n" "${BOLD}${RED}${message}${RESET}"
}

function print_red() {
    local message="$*"
    printf "%s\n" "${BOLD}${RED}${message}${RESET}"
}

function print_yellow() {
    local message="$*"
    printf "%s\n" "${BOLD}${YELLOW}${message}${RESET}"
}

function print_green() {
    local message="$*"
    printf "%s\n" "${BOLD}${GREEN}${message}${RESET}"
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
