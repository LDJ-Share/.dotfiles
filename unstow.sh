#!/usr/bin/env bash
DOTFILES="${1:-$(dirname "$0")}"
cd "$DOTFILES"
echo "Unstowing dotfiles from $DOTFILES"
stow -D .
