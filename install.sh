

set -euo pipefail

PROJECT_DIR="$HOME/nixpkg"
INSTALL_DIR="$HOME/.local/bin"
BINARY="$INSTALL_DIR/nixpkg"

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

echo
echo -e "${CYAN}${BOLD}❄ nixpkg installer${RESET}"
echo -e "${DIM}────────────────────────────────────────────${RESET}"
echo


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



step "Checking dependencies"

if ! command -v nix >/dev/null 2>&1; then
    error "Nix was not found."
    echo
    echo "  nixpkg requires Nix to be installed."
    echo
    exit 1
fi

success "Nix found"



if command -v cargo >/dev/null 2>&1; then

    success "Cargo found"

else

    warning "Cargo not found"

    echo
    echo "  Cargo is required to build nixpkg."
    echo

    read -r -p "  Is your NixOS system using flakes? [y/N] " answer
    echo

    case "$answer" in
        y|Y|yes|YES|Yes)
            USE_FLAKES=true
            ;;
        *)
            USE_FLAKES=false
            ;;
    esac

    if [ "$USE_FLAKES" = true ]; then

        step "Installing Cargo with Nix flakes"

        if ! nix profile install nixpkgs
            echo
            error "Failed to install Cargo."
            echo
            echo "  Make sure flakes are enabled on your system."
            echo
            exit 1
        fi

    else

        step "Installing Cargo with traditional Nix"

        if ! nix-env -iA nixpkgs.cargo; then
            echo
            error "Failed to install Cargo."
            echo
            echo "  Make sure nixpkgs is available through your"
            echo "  configured Nix channels."
            echo
            exit 1
        fi

    fi


    export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"

    if ! command -v cargo >/dev/null 2>&1; then
        echo
        error "Cargo was installed, but could not be found in PATH."
        echo
        echo "  Try opening a new terminal and running:"
        echo
        echo "    cargo --version"
        echo
        exit 1
    fi

    success "Cargo installed"

fi

echo




step "Creating project"

mkdir -p "$PROJECT_DIR/src"
mkdir -p "$INSTALL_DIR"


if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$(id -u):$(id -g)" "$PROJECT_DIR" 2>/dev/null || true
fi

success "Project ready"


cat > "$PROJECT_DIR/Cargo.toml" <<'EOF'
[package]
name = "nixpkg"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF



cat > "$PROJECT_DIR/src/ui.rs" <<'EOF'
pub const RESET: &str = "\x1b[0m";
pub const CYAN: &str = "\x1b[36m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const RED: &str = "\x1b[31m";
pub const DIM: &str = "\x1b[2m";
pub const BOLD: &str = "\x1b[1m";

pub fn header() {
    println!();
    println!("{CYAN}╭──────────────────────────────────────────╮{RESET}");
    println!("{CYAN}│  ❄ nixpkg                                │{RESET}");
    println!("{CYAN}╰──────────────────────────────────────────╯{RESET}");
    println!();
}

pub fn success(message: &str) {
    println!("  {GREEN}✓{RESET} {message}");
}

pub fn warning(message: &str) {
    println!("  {YELLOW}!{RESET} {message}");
}

pub fn error(message: &str) {
    eprintln!("  {RED}✗{RESET} {message}");
}

pub fn info(message: &str) {
    println!("  {CYAN}•{RESET} {message}");
}

pub fn package(message: &str) {
    println!("  {CYAN}Package:{RESET} {message}");
}

pub fn config(message: &str) {
    println!("  {CYAN}Configuration:{RESET} {message}");
}

pub fn section(title: &str) {
    println!();
    println!("  {BOLD}{title}{RESET}");
    println!("  {DIM}────────────────────────────────────────{RESET}");
    println!();
}

pub fn diff_add(message: &str) {
    println!("    {GREEN}+ {message}{RESET}");
}

pub fn diff_remove(message: &str) {
    println!("    {RED}- {message}{RESET}");
}

pub fn package_item(message: &str) {
    println!("    {CYAN}•{RESET} {message}");
}

pub fn tip(message: &str) {
    println!();
    println!("  {DIM}Tip: {message}{RESET}");
}
EOF


cat > "$PROJECT_DIR/src/config.rs" <<'EOF'
use std::fs;
use std::path::PathBuf;

pub fn find_config() -> Result<PathBuf, String> {
    let path = PathBuf::from("/etc/nixos/configuration.nix");

    if path.exists() {
        Ok(path)
    } else {
        Err("Could not find /etc/nixos/configuration.nix".to_string())
    }
}

pub fn read_config(path: &PathBuf) -> Result<String, String> {
    fs::read_to_string(path)
        .map_err(|error| format!("Failed to read configuration: {error}"))
}

pub fn write_config(path: &PathBuf, contents: &str) -> Result<(), String> {
    fs::write(path, contents)
        .map_err(|error| format!("Failed to write configuration: {error}"))
}

pub fn backup_config(path: &PathBuf) -> Result<PathBuf, String> {
    let backup_path =
        PathBuf::from(format!("{}.nixadd-backup", path.display()));

    fs::copy(path, &backup_path)
        .map_err(|error| format!("Failed to create backup: {error}"))?;

    Ok(backup_path)
}

pub fn find_system_packages(contents: &str) -> Result<(usize, usize), String> {
    let property = "environment.systemPackages";

    let mut line_start = 0;

    for line in contents.lines() {
        let trimmed = line.trim();

        if !trimmed.starts_with('#') {
            if let Some(relative_pos) = line.find(property) {
                let property_pos = line_start + relative_pos;

                let after_property =
                    &contents[property_pos + property.len()..];

                let start_offset = after_property
                    .find('[')
                    .ok_or_else(|| {
                        "Could not find package list '['".to_string()
                    })?;

                let start =
                    property_pos + property.len() + start_offset;

                let after_start = &contents[start + 1..];

                let end_offset = after_start
                    .find(']')
                    .ok_or_else(|| {
                        "Could not find package list ']'".to_string()
                    })?;

                let end = start + 1 + end_offset;

                return Ok((start, end));
            }
        }

        line_start += line.len() + 1;
    }

    Err("Could not find environment.systemPackages".to_string())
}

pub fn package_exists(contents: &str, package: &str) -> bool {
    let (start, end) = match find_system_packages(contents) {
        Ok(positions) => positions,
        Err(_) => return false,
    };

    let package_list = &contents[start + 1..end];

    package_list
        .split_whitespace()
        .any(|item| item == package)
}

pub fn add_package(
    contents: &str,
    package: &str,
) -> Result<String, String> {
    let (start, end) = find_system_packages(contents)?;

    let package_list = &contents[start + 1..end];

    let indentation = package_list
        .lines()
        .rev()
        .find(|line| !line.trim().is_empty())
        .map(|line| {
            line.chars()
                .take_while(|c| c.is_whitespace())
                .collect::<String>()
        })
        .unwrap_or_else(|| "  ".to_string());

    let mut result =
        String::with_capacity(contents.len() + package.len() + 8);

    result.push_str(&contents[..end]);

    if !package_list.ends_with('\n') {
        result.push('\n');
    }

    result.push_str(&indentation);
    result.push_str(package);

    result.push_str(&contents[end..]);

    Ok(result)
}

pub fn remove_package(
    contents: &str,
    package: &str,
) -> Result<String, String> {
    let (start, end) = find_system_packages(contents)?;

    let package_list = &contents[start + 1..end];

    let mut found = false;
    let mut new_package_list = String::new();

    for line in package_list.lines() {
        let trimmed = line.trim();

        if trimmed == package {
            found = true;
            continue;
        }

        new_package_list.push_str(line);
        new_package_list.push('\n');
    }

    if !found {
        return Err(format!(
            "Package '{package}' is not configured."
        ));
    }

    while new_package_list.ends_with("\n\n") {
        new_package_list.pop();
    }

    let mut result = String::with_capacity(contents.len());

    result.push_str(&contents[..start + 1]);
    result.push_str(&new_package_list);

    if !new_package_list.is_empty()
        && !new_package_list.ends_with('\n')
    {
        result.push('\n');
    }

    result.push_str(&contents[end..]);

    Ok(result)
}

pub fn create_system_packages(
    contents: &str,
    package: &str,
) -> String {
    let insert_position = contents.rfind('}').unwrap_or(contents.len());

    let mut result =
        String::with_capacity(contents.len() + package.len() + 70);

    result.push_str(&contents[..insert_position]);

    result.push_str(
        "\n  environment.systemPackages = with pkgs; [\n    ",
    );

    result.push_str(package);

    result.push_str("\n  ];\n");

    result.push_str(&contents[insert_position..]);

    result
}
EOF



cat > "$PROJECT_DIR/src/main.rs" <<'EOF'
use std::env;
use std::io::{self, Write};
use std::process::Command;

mod config;
mod ui;

fn print_credits() {
    ui::header();

    println!("  nixpkg");
    println!("  A simple CLI for managing NixOS packages.");
    println!();
    println!("  Created by Formidible");
    println!("  Written in Rust 🦀");
    println!("  Built for NixOS ❄");
    println!();
    println!("  GitHub: github.com/formidible");
    println!();
}

fn print_usage() {
    ui::header();

    println!("  Usage:");
    println!();

    println!("    nixpkg <package>");
    println!("    nixpkg <package> --dry-run");
    println!("    nixpkg <package> --rebuild");
    println!();

    println!("    nixpkg --remove <package>");
    println!("    nixpkg --remove <package> --dry-run");
    println!("    nixpkg --remove <package> --rebuild");
    println!();

    println!("    nixpkg --credits");
    println!();
}

fn confirm() -> bool {
    print!("  Apply this change? [y/N] ");
    io::stdout().flush().ok();

    let mut answer = String::new();

    if io::stdin().read_line(&mut answer).is_err() {
        return false;
    }

    answer.trim().eq_ignore_ascii_case("y")
}

fn rebuild(package: &str) {
    ui::section("NixOS rebuild");
    ui::info("Running nixos-rebuild switch...");

    match Command::new("nixos-rebuild")
        .arg("switch")
        .status()
    {
        Ok(status) if status.success() => {
            println!();
            ui::success("NixOS rebuilt successfully.");
            ui::success(&format!("{package} is now installed."));
        }

        Ok(status) => {
            println!();
            ui::error(&format!(
                "nixos-rebuild failed with status: {status}"
            ));
            ui::warning(
                "The configuration was updated, but the system was NOT rebuilt.",
            );
            std::process::exit(1);
        }

        Err(error) => {
            println!();
            ui::error(&format!("Failed to run nixos-rebuild: {error}"));
            ui::warning(
                "The configuration was updated, but the system was NOT rebuilt.",
            );
            std::process::exit(1);
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() == 1 {
        print_usage();
        std::process::exit(1);
    }

    match args[1].as_str() {
        "--credits" => {
            print_credits();
            return;
        }

        "--help" | "-h" => {
            print_usage();
            return;
        }

        _ => {}
    }

    let remove = args.iter().any(|arg| arg == "--remove");
    let dry_run = args.iter().any(|arg| arg == "--dry-run");
    let rebuild_enabled = args.iter().any(|arg| arg == "--rebuild");

    let package = if remove {
        match args.get(2) {
            Some(package) if !package.starts_with("--") => package,

            _ => {
                ui::error("Missing package name.");
                println!();
                println!("  Usage: nixpkg --remove <package>");
                println!();
                std::process::exit(1);
            }
        }
    } else {
        match args.get(1) {
            Some(package) if !package.starts_with("--") => package,

            _ => {
                ui::error("Missing package name.");
                print_usage();
                std::process::exit(1);
            }
        }
    };

    ui::header();
    ui::package(package);

    if remove {
        println!("  {}Action:{} remove", ui::CYAN, ui::RESET);
    } else {
        println!("  {}Action:{} add", ui::CYAN, ui::RESET);
    }

    ui::config("/etc/nixos/configuration.nix");

    if dry_run {
        println!("  {}Mode:{} dry run", ui::CYAN, ui::RESET);
    }

    if rebuild_enabled {
        println!("  {}Mode:{} rebuild", ui::CYAN, ui::RESET);
    }

    let path = match config::find_config() {
        Ok(path) => path,
        Err(error) => {
            ui::error(&error);
            std::process::exit(1);
        }
    };

    ui::success("Configuration found");

    let contents = match config::read_config(&path) {
        Ok(contents) => contents,
        Err(error) => {
            ui::error(&error);
            std::process::exit(1);
        }
    };

    if remove {
        if !config::package_exists(&contents, package) {
            println!();
            ui::warning(&format!(
                "Package '{package}' is not configured."
            ));
            ui::info("Nothing to do.");
            println!();
            return;
        }

        ui::success("Package found");
        ui::section("Proposed changes");

        println!("    environment.systemPackages = with pkgs; [");

        let (start, end) = match config::find_system_packages(&contents) {
            Ok(positions) => positions,
            Err(error) => {
                ui::error(&error);
                std::process::exit(1);
            }
        };

        let package_list = &contents[start + 1..end];

        for line in package_list.lines() {
            if line.trim() == package {
                ui::diff_remove(package);
            } else if !line.trim().is_empty() {
                println!("      {}", line.trim());
            }
        }

        println!("    ];");

        if dry_run {
            ui::warning("Dry run — no changes made.");
            println!();
            return;
        }

        println!();

        if !confirm() {
            println!();
            ui::info("Cancelled — no changes made.");
            println!();
            return;
        }

        println!();
        ui::info("Creating backup...");

        if let Err(error) = config::backup_config(&path) {
            ui::error(&format!("Failed to create backup: {error}"));
            ui::error("Configuration was NOT modified.");
            std::process::exit(1);
        }

        ui::success(&format!(
            "Backup created: {}.nixadd-backup",
            path.display()
        ));

        let modified = match config::remove_package(&contents, package) {
            Ok(modified) => modified,
            Err(error) => {
                ui::error(&format!("Failed to remove package: {error}"));
                std::process::exit(1);
            }
        };

        if let Err(error) = config::write_config(&path, &modified) {
            ui::error(&format!("Failed to write configuration: {error}"));
            ui::warning(
                "Your original configuration is still backed up.",
            );
            std::process::exit(1);
        }

        println!();
        ui::success("Configuration updated.");
        ui::success(&format!("{package} removed successfully."));

        if rebuild_enabled {
            rebuild(package);
        } else {
            ui::tip("Run 'sudo nixos-rebuild switch' to apply the removal.");
        }

        println!();
        return;
    }

    if config::package_exists(&contents, package) {
        println!();
        ui::warning(&format!(
            "Package '{package}' is already configured."
        ));
        ui::info("Nothing to do.");
        println!();
        return;
    }

    ui::success("Package not already installed");
    ui::section("Proposed changes");

    println!("    environment.systemPackages = with pkgs; [");
    println!("      ...");
    ui::diff_add(package);
    println!("    ];");

    if dry_run {
        ui::warning("Dry run — no changes made.");
        println!();
        return;
    }

    println!();

    if !confirm() {
        println!();
        ui::info("Cancelled — no changes made.");
        println!();
        return;
    }

    println!();
    ui::info("Creating backup...");

    if let Err(error) = config::backup_config(&path) {
        ui::error(&format!("Failed to create backup: {error}"));
        ui::error("Configuration was NOT modified.");
        std::process::exit(1);
    }

    ui::success(&format!(
        "Backup created: {}.nixadd-backup",
        path.display()
    ));

    let modified = match config::add_package(&contents, package) {
        Ok(modified) => modified,
        Err(error) => {
            ui::error(&format!(
                "Failed to modify configuration: {error}"
            ));
            std::process::exit(1);
        }
    };

    if let Err(error) = config::write_config(&path, &modified) {
        ui::error(&format!("Failed to write configuration: {error}"));
        ui::warning(
            "Your original configuration is still backed up.",
        );
        std::process::exit(1);
    }

    println!();
    ui::success("Configuration updated.");
    ui::success(&format!("{package} added successfully."));

    if rebuild_enabled {
        rebuild(package);
    } else {
        ui::tip("Run 'sudo nixos-rebuild switch' to apply it.");
    }

    println!();
}
EOF


step "Building nixpkg"

cd "$PROJECT_DIR"

RUSTFLAGS="-Awarnings" cargo build --release >/dev/null

success "Build complete"



step "Installing binary"

install -m 755 \
    "$PROJECT_DIR/target/release/nixpkg" \
    "$BINARY"

success "Installed to ~/.local/bin/nixpkg"


step "Configuring PATH"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

add_path() {
    local shell_file="$1"

    if [ -f "$shell_file" ]; then
        if ! grep -Fqx "$PATH_LINE" "$shell_file"; then
            printf '\n# nixpkg\n%s\n' "$PATH_LINE" >> "$shell_file"
        fi
    fi
}

add_path "$HOME/.bashrc"
add_path "$HOME/.zshrc"

if [ -d "$HOME/.config/fish" ]; then
    if ! grep -Fqx 'fish_add_path $HOME/.local/bin' \
        "$HOME/.config/fish/config.fish" 2>/dev/null; then

        printf '\n# nixpkg\nfish_add_path $HOME/.local/bin\n' \
            >> "$HOME/.config/fish/config.fish"
    fi
fi

export PATH="$INSTALL_DIR:$PATH"

success "PATH configured"


echo
echo -e "${DIM}────────────────────────────────────────────${RESET}"

if command -v nixpkg >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} ${BOLD}nixpkg is ready!${RESET}"
else
    warning "nixpkg installed, but is not currently in PATH"
fi

echo -e "${DIM}────────────────────────────────────────────${RESET}"
echo

printf "  %-9s %s\n" "Binary" "$BINARY"
printf "  %-9s %s\n" "Project" "$PROJECT_DIR"

echo
echo -e "  ${BOLD}Try it:${RESET}"
echo
echo "    nixpkg --help"
echo "    nixpkg firefox --dry-run"
echo

echo -e "${DIM}────────────────────────────────────────────${RESET}"
echo
