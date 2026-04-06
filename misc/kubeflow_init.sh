#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

apt update && apt install -y rsync zsh gh aria2 less tzdata ncdu bash-completion

# timezone
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
echo 'Asia/Seoul' | tee /etc/timezone > /dev/null

# dotfiles
curl -fsSL https://raw.githubusercontent.com/yehogwon/dotfiles/main/bin/install | NONINTERACTIVE_DOTFILES=1 bash
locale-gen en_US.UTF-8

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# kubectl shell completion
echo -e "\nsource <(kubectl completion zsh)\n" >> ~/.zshrc
echo -e "\nsource <(kubectl completion bash)\n" >> ~/.bashrc
