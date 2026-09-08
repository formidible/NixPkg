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
    println!("  GitHub: github.com/formidible/NixPkg");
    println!("   Please Star The Repo! ❤️");
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

    println!("    nixpkg --search <term>");
    println!("    nixpkg --credits");
    println!();
}

fn search(term: &str) -> i32 {
    ui::header();
    ui::section(&format!("Searching nixpkgs for '{term}'"));

    let pattern = format!("^{}$", escape_regex(term));

    match Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "search",
            "nixpkgs",
            &pattern,
        ])
        .output()
    {
        Ok(output) if output.status.success() => {
            let results = String::from_utf8_lossy(&output.stdout);

            if results.trim().is_empty() {
                ui::info("No exact package match found.");
            } else {
                print_formatted_results(&results);
            }

            0
        }
        Ok(output) => {
            ui::error(&format!("nix search failed with status: {}", output.status));

            let details = String::from_utf8_lossy(&output.stderr);
            if let Some(details) = details.lines().find(|line| !line.trim().is_empty()) {
                ui::error(details.trim());
            }

            1
        }
        Err(error) => {
            ui::error(&format!("Could not run nix search: {error}"));
            ui::tip("Install Nix or make sure the nix command is on your PATH.");
            1
        }
    }
}

fn escape_regex(value: &str) -> String {
    value
        .chars()
        .flat_map(|character| {
            if matches!(
                character,
                '.' | '^' | '$' | '*' | '+' | '?' | '(' | ')' | '[' | ']' | '{'
                    | '}' | '|' | '\\'
            ) {
                vec!['\\', character]
            } else {
                vec![character]
            }
        })
        .collect()
}

fn print_formatted_results(results: &str) {
    let mut first_result = true;

    for line in results.lines() {
        let line = line.trim();

        if line.is_empty() {
            continue;
        }

        if line == "*" {
            continue;
        }

        if let Some(entry) = line
            .strip_prefix("- ")
            .or_else(|| line.strip_prefix("* "))
        {
            if !first_result {
                println!();
            }
            first_result = false;

            let entry = entry
                .strip_prefix("legacyPackages.x86_64-linux.")
                .or_else(|| entry.strip_prefix("legacyPackages."))
                .unwrap_or(entry);
            let entry = entry
                .split_once('.')
                .map(|(_, package)| package)
                .unwrap_or(entry);

            println!("  {entry}");
        } else {
            println!("    {line}");
        }
    }
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

    if args[1] == "--credits" {
        print_credits();
        return;
    }

    if args[1] == "--search" {
        let term = match args.get(2) {
            Some(term) if !term.starts_with('-') => term,
            _ => {
                ui::error("Missing search term.");
                println!("  Usage: nixpkg --search <term>");
                std::process::exit(1);
            }
        };

        std::process::exit(search(term));
    }

    if args[1] == "--help" || args[1] == "-h" {
        print_usage();
        return;
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

    ui::config(&path.display().to_string());
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
            "Backup created: {}.nixpkg-backup",
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

    if config::has_system_packages(&contents) {
        println!("    environment.systemPackages = with pkgs; [");
        println!("      ...");
    } else {
        ui::info("No environment.systemPackages list found; it will be created.");
        println!("    environment.systemPackages = with pkgs; [");
    }
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
        "Backup created: {}.nixpkg-backup",
        path.display()
    ));

    let modified = if config::has_system_packages(&contents) {
        match config::add_package(&contents, package) {
            Ok(modified) => modified,
            Err(error) => {
                ui::error(&format!(
                    "Failed to modify configuration: {error}"
                ));
                std::process::exit(1);
            }
        }
    } else {
        config::create_system_packages(&contents, package)
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
