#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
BINARY="$INSTALL_DIR/nixpkg"

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'


step() {
    echo -e "  ${CYAN}→${RESET} $1"
}

success() {
    echo -e "  ${GREEN}✓${RESET} $1"
}

warning() {
    echo -e "  ${YELLOW}!${RESET} $1"
}

error() {
    echo -e "  ${RED}✗${RESET} $1"
}


echo
echo -e "${CYAN}❄ nixpkg installer${RESET}"
echo


step "Checking dependencies"


if ! command -v nix >/dev/null 2>&1; then
    error "Nix not found."
    exit 1
fi

success "Nix found"


if ! command -v cargo >/dev/null 2>&1; then

    warning "Cargo not found"
    step "Installing Cargo"

    nix profile install nixpkgs#cargo

    export PATH="$HOME/.nix-profile/bin:$PATH"
fi


if ! command -v cargo >/dev/null 2>&1; then
    error "Cargo installation failed."
    exit 1
fi

success "Cargo found"



step "Checking project"


cd "$PROJECT_DIR"


if [ ! -f Cargo.toml ]; then
    error "Cargo.toml missing."
    echo
    echo "This does not look like a nixpkg source checkout."
    exit 1
fi


if [ ! -f src/main.rs ]; then
    error "src/main.rs missing."
    exit 1
fi


success "Project found"



step "Building nixpkg"


cargo build --release


success "Build complete"



step "Installing binary"


mkdir -p "$INSTALL_DIR"


install -m 755 \
    target/release/nixpkg \
    "$BINARY"


success "Installed $BINARY"



step "Configuring PATH"


PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'


for FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do

    if [ -f "$FILE" ]; then

        if ! grep -Fxq "$PATH_LINE" "$FILE"; then
            echo >> "$FILE"
            echo "# nixpkg" >> "$FILE"
            echo "$PATH_LINE" >> "$FILE"
        fi

    fi

done


if [ -d "$HOME/.config/fish" ]; then

    FISH="$HOME/.config/fish/config.fish"

    if ! grep -Fxq 'fish_add_path $HOME/.local/bin' "$FISH" 2>/dev/null; then
        echo >> "$FISH"
        echo "# nixpkg" >> "$FISH"
        echo 'fish_add_path $HOME/.local/bin' >> "$FISH"
    fi

fi


export PATH="$INSTALL_DIR:$PATH"


success "PATH configured"


echo
echo "────────────────────────────────"
echo -e "${GREEN}✓ nixpkg installed${RESET}"
echo
echo "Try:"
echo
echo "  nixpkg --help"
echo "  nixpkg firefox --dry-run"
echo
echo "Binary:"
echo "  $BINARY"
echo
echo "────────────────────────────────"
