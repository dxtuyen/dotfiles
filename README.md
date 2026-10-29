# dotfiles

Personal NixOS and Home Manager configuration for an `x86_64-linux` laptop, managed with Nix flakes.

Sway on Wayland, Gruvbox Material, Foot, Bash, and Neovim. Includes Vietnamese input with Fcitx5/Lotus, development tools, and laptop power management.

## Usage

From the repository root on the configured laptop:

```bash
sudo nixos-rebuild switch --flake .#laptop
```

For another machine, first [adapt the hardware and user settings](docs/README.md#adapt-to-another-machine).

## Layout

```text
home/           Home Manager, applications, and desktop workflows
hosts/          Host configuration and hardware settings
modules/nixos/  System modules and services
pkgs/           Local package definitions
tests/          Workflow regression tests
docs/           Guides and reference
```

## Documentation

See the [configuration notes](docs/README.md) for editing, desktop shortcuts, and maintenance.
