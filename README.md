# nixpkg

A simple Rust CLI for adding and removing packages from your NixOS configuration.

`nixpkg` directly edits:

```text
/etc/nixos/configuration.nix
```

No package database. No complicated setup. Just a small tool that makes managing `environment.systemPackages` easier.

## Install

```bash
git clone https://github.com/formidible/NixPkg.git
cd NixPkg
./install.sh
```

The installer builds `nixpkg` and installs it to:

```text
~/.local/bin/nixpkg
```

It also configures your PATH.

## Usage

### Add a package

```bash
nixpkg firefox
```

### Remove a package

```bash
nixpkg --remove firefox
```

### Preview a change

```bash
nixpkg firefox --dry-run
```

### Add a package and rebuild

```bash
nixpkg firefox --rebuild
```

### Remove a package and rebuild

```bash
nixpkg --remove firefox --rebuild
```

## Commands

| Command                               | Description                  |
| ------------------------------------- | ---------------------------- |
| `nixpkg <package>`                    | Add a package                |
| `nixpkg <package> --dry-run`          | Preview an addition          |
| `nixpkg <package> --rebuild`          | Add a package and rebuild    |
| `nixpkg --remove <package>`           | Remove a package             |
| `nixpkg --remove <package> --dry-run` | Preview a removal            |
| `nixpkg --remove <package> --rebuild` | Remove a package and rebuild |
| `nixpkg --help`                       | Show help                    |
| `nixpkg --credits`                    | Show credits                 |

## How it works

If your configuration contains:

```nix
environment.systemPackages = with pkgs; [
  git
  vim
];
```

Running:

```bash
nixpkg firefox
```

adds `firefox` to the list.

Before making a change, `nixpkg` creates a backup and asks for confirmation.

Using `--dry-run` shows the proposed change without modifying your configuration.

Using `--rebuild` runs:

```bash
nixos-rebuild switch
```

after the configuration has been updated.

## Requirements

* NixOS
* Nix
* Cargo

If Cargo isn't installed, the installer can install it for you.

## Disclaimer

`nixpkg` modifies your NixOS configuration and can run `nixos-rebuild`.

**Use it at your own risk.**

Make sure you have a working backup or recovery option before making changes to your system.

## Why?

I wanted a simple command for:

```text
"put this package in my NixOS config"
```

So I made one.

Written in Rust.
Built for NixOS.

## License

MIT License
