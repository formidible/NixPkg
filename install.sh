#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PROJECT_DIR="$(pwd)"
INSTALL_DIR="$HOME/.local/bin"
BINARY="$INSTALL_DIR/nixpkg"

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
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
echo -e "${CYAN}${BOLD}❄ nixpkg installer${RESET}"
echo -e "${DIM}────────────────────────────────${RESET}"
echo


step "Checking dependencies"

if ! command -v nix >/dev/null 2>&1; then
    error "Nix not found."
    exit 1
fi

success "Nix found"


if command -v cargo >/dev/null 2>&1; then
    success "Cargo found"
else
    warning "Cargo not found"
    echo
    echo "Install cargo first:"
    echo
    echo "  nix-shell -p cargo"
    echo
    exit 1
fi


step "Checking project"

if [ ! -f "Cargo.toml" ]; then

    warning "Cargo.toml missing"

    echo
    echo "  Initializing Rust project..."
    echo

    cargo init --name nixpkg .

    success "Rust project created"

fi

success "Project ready"


mkdir -p "$INSTALL_DIR"


step "Building nixpkg"

cargo build --release

success "Build complete"


step "Installing binary"

install -m 755 \
    target/release/nixpkg \
    "$BINARY"

success "Installed $BINARY"


step "Configuring PATH"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'


if [ -f "$HOME/.bashrc" ]; then
    if ! grep -Fxq "$PATH_LINE" "$HOME/.bashrc"; then
        echo "$PATH_LINE" >> "$HOME/.bashrc"
    fi
fi


if [ -f "$HOME/.zshrc" ]; then
    if ! grep -Fxq "$PATH_LINE" "$HOME/.zshrc"; then
        echo "$PATH_LINE" >> "$HOME/.zshrc"
    fi
fi


export PATH="$INSTALL_DIR:$PATH"

success "PATH configured"


echo
echo -e "${DIM}────────────────────────────────${RESET}"

if command -v nixpkg >/dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}✓ nixpkg installed${RESET}"
else
    warning "Restart your terminal before using nixpkg"
fi


echo
echo "Try:"
echo
echo "  nixpkg --help"
echo
echo "Binary:"
echo "  $BINARY"
echo
echo -e "${DIM}────────────────────────────────${RESET}"
