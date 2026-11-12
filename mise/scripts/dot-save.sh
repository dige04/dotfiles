#!/bin/bash
# mise run dot:save: commit every change in ~/.dotfiles with a message such as
# "Update .zshrc Add .config/foo/config.toml", then push it.
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"

git -C "$DOTFILES_DIR" add -A
if git -C "$DOTFILES_DIR" diff --cached --quiet; then
    echo "Nothing to save."
    exit 0
fi

message="$(git -C "$DOTFILES_DIR" diff --cached --name-status | awk '
    { path = $NF; sub(/^home\//, "", path) }
    $1 ~ /^A/ { printf "%sAdd %s", sep, path; sep = " "; next }
    $1 ~ /^D/ { printf "%sRemove %s", sep, path; sep = " "; next }
    $1 ~ /^R/ { printf "%sRename %s", sep, path; sep = " "; next }
    { printf "%sUpdate %s", sep, path; sep = " " }
')"

git -C "$DOTFILES_DIR" commit -q -m "$message"
git -C "$DOTFILES_DIR" log --oneline -1
git -C "$DOTFILES_DIR" pull -q --rebase
git -C "$DOTFILES_DIR" push -q
echo "Pushed."
