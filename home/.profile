# set PATH so it includes user's private bin if it exists
export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/bin

if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d /opt/homebrew/bin ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi

if [ -f "$HOME/.local/bin/mise" ]; then
    eval "$($HOME/.local/bin/mise activate bash --shims)"
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
