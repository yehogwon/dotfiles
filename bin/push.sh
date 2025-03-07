#! /bin/bash

CWD=$(pwd)

echo "Are you sure you want to download dotfiles and link them to your local ones?"
echo " (y/n) > "
read -n 1 -s answer
echo

function cd_exit() {
    cd "$CWD"
    exit "$1"
}

if [ "$answer" = "y" ]; then
    echo "Adding dotfiles to GitHub and committing..."
    cd "$(dirname "$0")/.."
    if git add .; then
        echo "Dotfiles added successfully."
    else
        echo "Failed to add dotfiles."
        cd_exit 1
    fi

    if git commit -m "$(date +"%Y.%m.%d-%H:%M:%S") ... Dotfiles Pushed"; then
        echo "Dotfiles committed successfully."
    else
        echo "Failed to commit dotfiles."
        cd_exit 1
    fi
    
    if git push origin main; then
        echo "Dotfiles pushed successfully."
    else
        echo "Failed to push dotfiles."
        cd_exit 1
    fi
else
    echo "Download cancelled."
    cd_exit 0
fi
