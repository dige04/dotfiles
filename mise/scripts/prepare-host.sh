#!/bin/bash
# mise bootstrap pre-packages hook: folders the shell and macOS defaults
# expect, and Rosetta 2. Runs on every bootstrap; each step skips work done.
set -euo pipefail

for dir in \
    "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.local/run" \
    "$HOME/.config" "$HOME/bin" \
    "$HOME/.cache/zsh/completions" "$HOME/.local/share/zsh" \
    "$HOME/Pictures/Screenshots"; do
    mkdir -p "$dir"
done
chmod 0700 "$HOME/.local/run"

# Rosetta 2 on Apple Silicon (needed by a few casks). setup.sh primes sudo.
if [[ "$(uname -m)" == "arm64" ]] && ! pgrep -q oahd; then
    echo "Installing Rosetta 2"
    sudo softwareupdate --install-rosetta --agree-to-license
fi
