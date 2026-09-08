# nixpkg

`nixpkg` is a small Rust CLI for adding and removing packages from a NixOS
configuration.

It edits `/etc/nixos/configuration.nix` directly, or `/etc/nixos/packages.nix`
when `configuration.nix` is not present. There is no package database or extra
service; it is simply a convenient way to maintain
`environment.systemPackages`.

## Install
```bash
git clone https://github.com/formidible/NixPkg.git
cd NixPkg
./install.sh
```

The installer builds the binary and places it at `~/.local/bin/nixpkg`.
It presents a menu. If Cargo is missing, option 2 adds `cargo`, `rustc`, and
`gcc` to the detected NixOS configuration file, creates a backup, and runs
`nixos-rebuild switch` before building. It also configures the user shell PATH
so `nixpkg` is available in new terminals.

## Usage

Add or remove a package:

```bash
nixpkg firefox
nixpkg --remove firefox
```

Preview a change without modifying the configuration:

```bash
nixpkg firefox --dry-run
nixpkg --remove firefox --dry-run
```

Update the configuration and rebuild the system:

```bash
nixpkg firefox --rebuild
nixpkg --remove firefox --rebuild
```

Search for an exact package name in nixpkgs:

```bash
nixpkg --search firefox
```

Search output is filtered to matching package results. The `nix-command` and
`flakes` features are enabled for that command only; the user's Nix
configuration is not changed.

View help or credits:

```bash
nixpkg --help
nixpkg --credits
```

## Commands

| Command | Description |
| --- | --- |
| `nixpkg <package>` | Add a package |
| `nixpkg <package> --dry-run` | Preview an addition |
| `nixpkg <package> --rebuild` | Add a package and rebuild |
| `nixpkg --remove <package>` | Remove a package |
| `nixpkg --remove <package> --dry-run` | Preview a removal |
| `nixpkg --remove <package> --rebuild` | Remove a package and rebuild |
| `nixpkg --search <term>` | Search nixpkgs |
| `nixpkg --help` | Show help |
| `nixpkg --credits` | Show credits |

## How changes work

Given:

```nix
environment.systemPackages = with pkgs; [
  git
  vim
];
```

running `nixpkg firefox` adds `firefox` to the list. If
`environment.systemPackages` is missing, nixpkg creates the list before
adding the package.

Before changing the file, nixpkg shows the proposed change, asks for
confirmation, creates `/etc/nixos/configuration.nix.nixpkg-backup`, and then
writes the updated configuration. `--dry-run` skips the confirmation and
write steps.

With `--rebuild`, nixpkg runs:

```bash
nixos-rebuild switch
```

after the file is updated.

## Requirements

- NixOS
- Nix
- Bash for the installer
- Cargo and a C compiler, or NixOS/Nix to install them during installation

The command must be able to read and write `/etc/nixos/configuration.nix`, or
`/etc/nixos/packages.nix` when the former is absent.
Depending on file permissions, you may need appropriate privileges.


## Disclaimer

By instaling this package you are aware that if it causes a malformation in your system configuration I am NOT liable for any issues. 

NixPkg installer does not yet port to your /local/bin so it will not automatically run globally. You need to add it to your path.




## Safety

`nixpkg` directly modifies your NixOS configuration and can run
`nixos-rebuild`. Review proposed changes and keep a separate recovery path
for your system before using it.

## License

MIT License
