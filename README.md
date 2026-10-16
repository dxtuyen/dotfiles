# NixOS Laptop Configuration

A personal NixOS configuration for an x86_64 laptop, managed with Nix flakes and Home Manager. It provides a Sway desktop on Wayland, a terminal-focused workflow, development tools, and laptop power management.

This repository is designed around one machine and one user. It can be adapted for another system, but it is not a drop-in installer: review the hardware configuration, username, disk layout, and personal settings before deploying it.

## System overview

- **Operating system:** NixOS unstable, pinned through `flake.lock`
- **Desktop:** Sway, Waybar, Mako, and Foot
- **Input:** Fcitx5 with Lotus
- **Shell:** Bash with Starship, fzf, zoxide, and direnv
- **User configuration:** Home Manager, integrated into the NixOS flake
- **Laptop features:** zram, hibernation, battery charge thresholds, key remapping, and firmware updates

## Repository layout

```text
.
├── flake.nix                 # Inputs, formatter, and the laptop build target
├── hosts/laptop/             # Host entry point and generated hardware settings
├── modules/nixos/            # Core, desktop, input, laptop, and service modules
├── pkgs/                     # Local package definitions
├── home/                     # Home Manager user environment
│   ├── shell/                # Bash and shell tools
│   ├── programs/             # User program configuration
│   ├── desktop/              # Graphical session and desktop integration
│   ├── features/             # Multi-part user workflows and integrations
│   ├── scripts/              # User commands; larger scripts use native .py/.sh files
│   ├── packages.nix          # User package selection
│   └── assets/               # Static user-level assets
└── docs/                     # Usage and installation guides
```

NixOS modules describe the machine and system services. Home Manager describes the user environment. Within Home Manager, `programs/` configures individual programs, `desktop/` groups the graphical session, and `features/` keeps related scripts and services with the workflow they support. Longer Python and shell programs live in source files next to their small Nix installation modules.

For a walkthrough of the modules, services, data locations, and maintenance flow, see the [system guide](docs/system-guide.md). The shorter [architecture map](docs/architecture.md) traces the module import path and desktop workflows.

## Use this configuration

Review and adapt the machine-specific values before building:

1. `hosts/laptop/hardware-configuration.nix` must match the target machine's disks and hardware. Generate it on the target system; do not reuse another machine's file.
2. `flake.nix` and `hosts/laptop/default.nix` define the host name, username, and build target.
3. `modules/nixos/` and `home/` contain personal system and user preferences. Check disk labels, sleep behavior, and package choices for your hardware.

To build the configured system on a machine that already runs NixOS:

```bash
sudo nixos-rebuild switch --flake .#laptop
```

This applies both the NixOS system configuration and its integrated Home Manager configuration. The optional `nh os switch` command is also enabled and points to `/home/doxuantuyen/nix-config` in this setup.

Format Nix files with:

```bash
nix fmt
```

## Documentation

- [Documentation index](docs/README.md) — choose an installation path.
- [System guide](docs/system-guide.md) — understand modules, services, workflows, and state.
- [QEMU practice guide](docs/06-Luyen-Tap-VM.md) — install the flake in an isolated virtual machine.
- [Personal laptop installation notes](docs/personal/cai-laptop.md) — hardware-specific notes for the author's laptop.

The laptop installation notes describe a particular disk layout and are intended for personal reference. Use the VM guide to learn the installation flow without changing a physical disk.

## Personal data

The repository contains system and application configuration, not personal files or credentials. Keep SSH private keys, passwords, documents, and personal wallpaper collections outside the repository and back them up separately.
