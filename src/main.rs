use std::env;
use std::io::{self, Write};
use std::process::Command;

mod config;
mod ui;

fn print_credits() {
    ui::header();

    println!("  nixadd");
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

    println!("    nixadd <package>");
    println!("    nixadd <package> --dry-run");
    println!("    nixadd <package> --rebuild");
    println!();

    println!("    nixadd --remove <package>");
    println!("    nixadd --remove <package> --dry-run");
    println!("    nixadd --remove <package> --rebuild");
    println!();

    println!("    nixadd --credits");
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

    if args[1] == "--credits" {
        print_credits();
        return;
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
                println!("  Usage: nixadd --remove <package>");
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
