#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

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

if command -v cargo >/dev/null 2>&1; then
    success "Cargo found"
elif command -v nix >/dev/null 2>&1; then
    success "Nix found; it will provide Cargo for the build"
else
    error "Neither Cargo nor Nix was found."
    exit 1
fi


step "Checking project"

if [ ! -f "Cargo.toml" ]; then
    error "Cargo.toml not found in the project directory."
    exit 1
fi

success "Project ready"


mkdir -p "$INSTALL_DIR"


step "Building nixpkg"

if command -v cargo >/dev/null 2>&1; then
    success "Cargo found"
    cargo build --release
else
    warning "Cargo not found; building with Nix"
    nix-shell -p cargo rustc --run 'cargo build --release'
fi

success "Build complete"


step "Installing binary"

install -m 755 \
    target/release/nixpkg \
    "$BINARY"

success "Installed $BINARY"


step "Configuring PATH"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

add_path_line() {
    local shell_file="$1"

    touch "$shell_file"
    if ! grep -Fxq "$PATH_LINE" "$shell_file"; then
        printf '\n%s\n' "$PATH_LINE" >> "$shell_file"
    fi
}

add_path_line "$HOME/.profile"

if [ -f "$HOME/.bashrc" ]; then
    add_path_line "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ]; then
    add_path_line "$HOME/.zshrc"
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
