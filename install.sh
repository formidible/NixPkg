#!/usr/bin/env bash
set -euo pipefail

# Resolve the project directory instead of relying on the directory from which
# the installer was started.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
BINARY="$INSTALL_DIR/nixpkg"
CONFIG_FILE="/etc/nixos/configuration.nix"

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

step() { echo -e "  ${CYAN}→${RESET} $1"; }
success() { echo -e "  ${GREEN}✓${RESET} $1"; }
warning() { echo -e "  ${YELLOW}!${RESET} $1"; }
error() { echo -e "  ${RED}✗${RESET} $1" >&2; }

if [[ ! -f "$PROJECT_DIR/Cargo.toml" ]]; then
    error "Cargo.toml not found next to install.sh."
    exit 1
fi

echo
echo -e "${CYAN}${BOLD}❄ nixpkg installer${RESET}"
echo -e "${DIM}────────────────────────────────${RESET}"
echo

step "Selecting how Cargo will be provided"
echo ""
echo "  1) Cargo is already installed"
echo "  2) Cargo isn't installed (add it to NixOS configuration)"
echo ""

if command -v cargo >/dev/null 2>&1; then
    default_choice=1
else
    default_choice=2
fi

read -r -p "  Choose [1/2] (default: $default_choice): " choice || true
choice="${choice:-$default_choice}"

case "$choice" in
    1)
        if ! command -v cargo >/dev/null 2>&1; then
            error "Cargo was not found. Choose option 2 to install it through NixOS."
            exit 1
        fi
        success "Cargo found: $(command -v cargo)"
        ;;
    2)
        if ! command -v nix >/dev/null 2>&1; then
            error "Nix is required to install Cargo through configuration.nix."
            error "Install Nix/NixOS first, then run this installer again."
            exit 1
        fi
        if [[ ! -f "$CONFIG_FILE" ]]; then
            error "Could not find $CONFIG_FILE"
            exit 1
        fi

        step "Adding Cargo and Rust to $CONFIG_FILE"
        temp_config="$(mktemp)"
        cleanup() { rm -f "$temp_config"; }
        trap cleanup EXIT

        # Keep the original configuration recoverable before changing it.
        sudo cp -- "$CONFIG_FILE" "${CONFIG_FILE}.nixpkg-installer-backup"

        # Add the tools to an existing environment.systemPackages list when
        # possible. Otherwise create the list inside the module.
        awk '
            function active(line) {
                sub(/^[[:space:]]*/, "", line)
                return line !~ /^#/ && line !~ /^\/\//
            }
            BEGIN { in_packages = 0; added = 0; has_cargo = 0; has_rustc = 0; has_gcc = 0 }
            {
                line = $0
                if (active(line) && line ~ /(^|[[:space:]])cargo([[:space:]]|$)/) has_cargo = 1
                if (active(line) && line ~ /(^|[[:space:]])rustc([[:space:]]|$)/) has_rustc = 1
                if (active(line) && line ~ /(^|[[:space:]])gcc([[:space:]]|$)/) has_gcc = 1
                if (!in_packages && active(line) && line ~ /environment\.systemPackages[[:space:]]*=/) {
                    in_packages = 1
                }
                if (in_packages && index(line, "]") > 0 && !added) {
                    close_bracket = index(line, "]")
                    print substr(line, 1, close_bracket - 1)
                    if (!has_cargo) print "    cargo"
                    if (!has_rustc) print "    rustc"
                    if (!has_gcc) print "    gcc"
                    print substr(line, close_bracket)
                    added = 1
                    in_packages = 0
                } else {
                    print line
                }
            }
            END {
                if (!added) {
                    print ""
                    print "  environment.systemPackages = with pkgs; ["
                    if (!has_cargo) print "    cargo"
                    if (!has_rustc) print "    rustc"
                    if (!has_gcc) print "    gcc"
                    print "  ];"
                }
            }
        ' "$CONFIG_FILE" > "$temp_config"

        sudo install -m 644 -- "$temp_config" "$CONFIG_FILE"
        success "Configuration updated"

        step "Activating Cargo with NixOS"
        sudo nixos-rebuild switch

        # The current shell does not automatically inherit the new system
        # profile, so include it explicitly for this build.
        if [[ -x /run/current-system/sw/bin/cargo ]]; then
            export PATH="/run/current-system/sw/bin:$PATH"
        fi
        if ! command -v cargo >/dev/null 2>&1; then
            error "Cargo is still unavailable after nixos-rebuild."
            exit 1
        fi
        success "Cargo is now available: $(command -v cargo)"
        ;;
    *)
        error "Please choose 1 or 2."
        exit 1
        ;;
esac

mkdir -p -- "$INSTALL_DIR"

step "Building nixpkg"
if command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; then
    cargo build --release --manifest-path "$PROJECT_DIR/Cargo.toml"
elif command -v nix >/dev/null 2>&1; then
    warning "No C compiler found; temporarily providing GCC with Nix"
    nix-shell -p cargo rustc gcc --run "cd '$PROJECT_DIR' && cargo build --release"
else
    error "A C compiler is required to build nixpkg, but neither GCC nor Nix was found."
    exit 1
fi
success "Build complete"

step "Installing binary"
install -m 755 -- "$PROJECT_DIR/target/release/nixpkg" "$BINARY"
success "Installed $BINARY"

step "Configuring PATH"
PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""

add_path_line() {
    local shell_file="$1"
    touch -- "$shell_file"
    if ! grep -Fqx -- "$PATH_LINE" "$shell_file"; then
        printf '\n%s\n' "$PATH_LINE" >> "$shell_file"
    fi
}

add_path_line "$HOME/.profile"
[[ -f "$HOME/.bashrc" ]] && add_path_line "$HOME/.bashrc"
[[ -f "$HOME/.zshrc" ]] && add_path_line "$HOME/.zshrc"
export PATH="$INSTALL_DIR:$PATH"
success "PATH configured"

echo
echo -e "${DIM}────────────────────────────────${RESET}"
if command -v nixpkg >/dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}✓ nixpkg installed and available${RESET}"
else
    warning "Open a new terminal or run: source ~/.profile"
fi
echo
echo "Try: nixpkg --help"
echo "Binary: $BINARY"
echo -e "${DIM}────────────────────────────────${RESET}"
