# Architecture

This repository has one NixOS host and one Home Manager user. The directories
separate machine configuration from the user's desktop and commands.

For a Vietnamese walkthrough of system modules, services, state locations, and
maintenance, see the [system guide](system-guide.md).

## Configuration path

```text
flake.nix
└── hosts/laptop/default.nix
    ├── modules/nixos/       NixOS services, hardware, and system settings
    └── home/                Home Manager configuration for the user
        ├── desktop/         Sway, Waybar, notifications, and desktop integration
        ├── features/        Workflows with their own scripts and services
        ├── scripts/         Reusable user commands grouped by purpose
        ├── programs/        Individual application settings
        └── shell/           Shell and command-line tools
```

`flake.nix` selects the laptop output and provides shared inputs. The host file
imports the NixOS modules and attaches Home Manager. `home/default.nix` then
imports the user-level modules.

## Desktop workflows

| Entry point | Configuration | Implementation |
|---|---|---|
| Sway keybindings | `home/desktop/sway.nix` | Commands in `home/scripts/desktop/` and `home/features/` |
| Waybar modules | `home/desktop/waybar.nix` | Countdown and system status modules |
| Sway window management | `home/desktop/sway.nix` | Native scratchpad/resize mode, swayview overview, and swayr history switcher |
| Countdown menu and timer | `home/features/countdown/default.nix` | `menu.nix` / `countdown-menu.sh`, `engine.nix` / `countdown-engine.sh`, `sleep-watch.nix` / `countdown-sleep-watch.sh`, and `services.nix` |
| Wallpaper workflow | `home/features/wallpaper/default.nix` | One fixed Gruvbox wallpaper rendered by swaybg for the Sway session |

The Nix modules install scripts and declare the services that run them. Longer
Python and Bash implementations live in adjacent source files so editors can
recognize their languages and the Nix stays focused on paths, dependencies, and
service setup.

## Tracing a behavior

Start at the keybinding or Waybar module, follow the referenced command name to
its Home Manager module, then check whether that module installs a script or
declares a systemd service. Sway window arrangement and resize behavior are
handled directly by Sway, while swayview and swayr provide workspace and focus
switching.
