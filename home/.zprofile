export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/bin

if [ -f "$HOME/.local/bin/mise" ]; then
    eval "$($HOME/.local/bin/mise activate zsh --shims)"
fi

# Homebrew prefix. mise bootstrap installs brew packages into /opt/homebrew
# without installing Homebrew itself, so fall back to plain PATH entries.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d /opt/homebrew/bin ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi
