#!/bin/bash
# =============================================================================
# New-Mac setup:
#   curl -fsSL https://raw.githubusercontent.com/dige04/dotfiles/main/setup.sh | bash
#
# Installs the Xcode Command Line Tools and mise, clones this repository to
# ~/.dotfiles, saves the git identity, links the mise config and runs
# `mise bootstrap` (brew packages, apps, dotfiles, macOS defaults, tools).
# Safe to run again: every step skips work that is already done.
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/dige04/dotfiles.git"
BRANCH="main"
DOTFILES_DIR="$HOME/.dotfiles"
MISE_CONFIG_DIR="$HOME/.config/mise"
# Oldest mise with everything the config uses (bootstrap, [dotfiles], macOS defaults).
MISE_MIN_VERSION="2026.11.0"

DEFAULT_GIT_NAME="Hieu Dinh"
DEFAULT_GIT_EMAIL="onedirection.hieu@gmail.com"

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Under `curl | bash` stdin is the script, so questions go to the terminal.
tty_available() { [[ -r /dev/tty && -w /dev/tty ]]; }

if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This setup is for macOS only."
    exit 1
fi

# -----------------------------------------------------------------------------
# sudo: ask once up front, then keep the credential alive, so the long
# unattended package install never stalls on a password prompt.
# -----------------------------------------------------------------------------
SUDO_KEEPALIVE_PID=""
stop_sudo_keepalive() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap stop_sudo_keepalive EXIT

ensure_sudo() {
    if ! sudo -n true 2>/dev/null; then
        if ! tty_available; then
            log_error "Need an admin password but there is no terminal. Run instead:"
            log_error "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/dige04/dotfiles/main/setup.sh)\""
            return 1
        fi
        log_info "Admin password needed once (Command Line Tools, /opt/homebrew, Rosetta, apps)."
        sudo -v || return 1
    fi
    while true; do
        sudo -n true 2>/dev/null || break
        sleep 60
        kill -0 "$$" 2>/dev/null || break
    done &
    SUDO_KEEPALIVE_PID=$!
}

# -----------------------------------------------------------------------------
# Xcode Command Line Tools. /usr/bin/git is a stub until they are installed,
# so ask xcrun for a real git instead of checking the command.
# -----------------------------------------------------------------------------
clt_installed() {
    local dev_dir
    dev_dir="$(/usr/bin/xcode-select -p 2>/dev/null)" || return 1
    [[ -d "$dev_dir" ]] && /usr/bin/xcrun --find git >/dev/null 2>&1
}

setup_clt() {
    if clt_installed; then
        log_info "Xcode Command Line Tools already installed"
        return 0
    fi

    log_info "Installing Xcode Command Line Tools (a few minutes)..."
    local marker="/tmp/.com.apple.dt.CLT.installondemand" label
    touch "$marker"
    label="$(softwareupdate -l 2>/dev/null | grep -E '^ *\* *Label: .*Command Line Tools' \
        | sed -E 's/^ *\* *Label: *//' | tail -1)" || label=""
    rm -f "$marker"

    if [[ -n "$label" ]]; then
        sudo softwareupdate -i "$label" --verbose || true
    fi

    if ! clt_installed; then
        # Fall back to Apple's dialog and wait for it.
        /usr/bin/xcode-select --install >/dev/null 2>&1 || true
        log_info "Finish the 'Install Command Line Tools' dialog; waiting for it..."
        local waited=0
        until clt_installed; do
            if (( waited >= 1800 )); then
                log_error "Command Line Tools still missing after 30 minutes. Run 'xcode-select --install', then this script again."
                exit 1
            fi
            sleep 10
            waited=$((waited + 10))
        done
    fi
    log_success "Xcode Command Line Tools installed"
}

setup_mise() {
    export PATH="$HOME/.local/bin:$PATH"
    if command_exists mise; then
        local current
        current="$(mise --version 2>/dev/null | awk '{print $1}')"
        if [[ "$(printf '%s\n' "$MISE_MIN_VERSION" "$current" | sort -V | head -1)" == "$MISE_MIN_VERSION" ]]; then
            log_info "mise $current already installed"
            return 0
        fi
        log_info "mise $current is older than $MISE_MIN_VERSION; updating..."
        mise self-update --yes
        return 0
    fi

    log_info "Installing mise..."
    curl -fsSL https://mise.run | sh
}

clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log_info "Dotfiles already at $DOTFILES_DIR; pulling..."
        git -C "$DOTFILES_DIR" pull --rebase --autostash -q || log_info "Pull failed; using the local copy."
        return 0
    fi
    log_info "Cloning $REPO_URL into $DOTFILES_DIR..."
    git clone -q -b "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
}

toml_string() {
    local value=${1//\\/\\\\}
    printf '"%s"' "${value//\"/\\\"}"
}

# The git identity is per machine: it goes into config.local.toml (never
# committed) and mise renders it into ~/.gitconfig.
setup_git_identity() {
    local local_config="$MISE_CONFIG_DIR/config.local.toml"
    local name="${DOTFILES_GIT_NAME:-}" email="${DOTFILES_GIT_EMAIL:-}"

    if [[ -f "$local_config" ]] && grep -qE '^git_name *=' "$local_config"; then
        log_info "Git identity already in $local_config"
        return 0
    fi

    if [[ -z "$name" || -z "$email" ]] && tty_available; then
        [[ -n "$name" ]] || read -r -p "Git name [$DEFAULT_GIT_NAME]: " name </dev/tty
        [[ -n "$email" ]] || read -r -p "Git email [$DEFAULT_GIT_EMAIL]: " email </dev/tty
    fi
    name="${name:-$DEFAULT_GIT_NAME}"
    email="${email:-$DEFAULT_GIT_EMAIL}"

    mkdir -p "$MISE_CONFIG_DIR"
    (umask 077 && printf '[vars]\ngit_name = %s\ngit_email = %s\n' \
        "$(toml_string "$name")" "$(toml_string "$email")" >>"$local_config")
    log_success "Git identity ($name <$email>) saved to $local_config"
}

link_mise_config() {
    local source="$DOTFILES_DIR/mise/config.toml" target="$MISE_CONFIG_DIR/config.toml"
    mkdir -p "$MISE_CONFIG_DIR"
    [[ -L "$target" && "$(readlink "$target")" == "$source" ]] && return 0
    if [[ -e "$target" || -L "$target" ]]; then
        mv "$target" "$target.bak-$(date +%Y%m%d-%H%M%S)"
        log_info "Moved the old $target aside (.bak-*)"
    fi
    ln -s "$source" "$target"
}

# mise replaces real files with links only with --force-dotfiles, which this
# script passes, so copy everything it is about to replace somewhere safe first.
backup_existing_targets() {
    local backup_dir rel target count=0
    backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

    while IFS= read -r rel; do
        rel="${rel#home/}"
        target="$HOME/$rel"
        [[ -e "$target" || -L "$target" ]] || continue
        [[ -L "$target" && "$(readlink "$target")" == "$DOTFILES_DIR/home/$rel" ]] && continue
        [[ "$rel" == ".gitconfig" ]] && grep -q 'mise:identity' "$target" && continue
        # A linked parent directory (karabiner) already points into the repo.
        [[ "$(cd "$(dirname "$target")" && pwd -P)" == "$DOTFILES_DIR/home/"* ]] && continue
        mkdir -p "$backup_dir/$(dirname "$rel")"
        cp -a "$target" "$backup_dir/$rel"
        count=$((count + 1))
    done < <(git -C "$DOTFILES_DIR" ls-files home; echo .gitconfig)

    if [[ $count -gt 0 ]]; then
        log_success "Backed up $count existing file(s) to $backup_dir"
    fi
}

main() {
    log_info "Setting up this Mac from $REPO_URL"

    setup_clt
    ensure_sudo || log_info "Continuing without cached sudo; later steps may ask for the password."
    setup_mise
    clone_dotfiles
    setup_git_identity
    link_mise_config
    backup_existing_targets

    log_info "Running mise bootstrap (brew packages, apps, dotfiles, macOS settings, tools)..."
    log_info "The first run downloads a lot; expect 15-40 minutes."
    if ! mise bootstrap --yes --force-dotfiles; then
        log_error "mise bootstrap stopped. Fix the step it names, then run: mise bootstrap"
        exit 1
    fi

    log_success "Done. Open a new terminal (or: exec zsh)."
    log_info "Next: gh auth login, then sign in to the apps. See ~/.dotfiles/README.md."
}

main "$@"
