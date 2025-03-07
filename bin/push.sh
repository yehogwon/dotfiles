#! /bin/bash

CWD=$(pwd)

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]:-$0}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
DOTFILES_DIR="$(realpath "$SCRIPT_DIR/..")" # does not end with a slash

function return() {
    cd "$CWD"
}

echo "Adding dotfiles to GitHub and committing..."
cd "$DOTFILES_DIR"
if git add .; then
    echo "Dotfiles added successfully."
else
    echo "Failed to add dotfiles."
    return
fi

if git commit -m "$(date +"%Y.%m.%d-%H:%M:%S") ~ Dotfiles Pushed 🚀"; then
    echo "Dotfiles committed successfully."
else
    echo "Failed to commit dotfiles."
    return
fi

if git push origin main; then
    echo "Dotfiles pushed successfully."
else
    echo "Failed to push dotfiles."
    return
fi

return
