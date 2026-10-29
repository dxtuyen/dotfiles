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
| Session lock, idle, and sleep | `home/desktop/session.nix` | Swaylock settings, session services, and the lock-screen / idle-suspend commands |
| Waybar modules | `home/desktop/waybar.nix` | Countdown and system status modules |
| Sway window management | `home/desktop/sway.nix` | Global automatic focus for urgent windows (including hidden scratchpad windows), native scratchpad/resize mode, toggleable terminal popup, Alt+Tab returns to the previously focused workspace, Mod+Tab workspace overview via swayview, and Waybar scratchpad count |
| Countdown menu and timer | `home/features/countdown/default.nix` | Installs `countdown-menu.sh`, `countdown-engine.sh`, and `countdown-sleep-watch.sh`; `services.nix` declares Countdown services |
| Wallpaper workflow | `home/features/wallpaper/default.nix` | `images.nix` generates desktop and lockscreen images from the shared palette at 1920×1080 by default, with optional host resolution overrides; swaybg and swaylock display the Nix store outputs |

The Nix modules install scripts and declare the services that run them. Longer
Python and Bash implementations live in adjacent source files so editors can
recognize their languages and the Nix stays focused on paths, dependencies, and
service setup.

Rofi's shared palette and the action/input themes live in `home/desktop/rofi.nix`.
`home/desktop/rofi-menu.sh` provides presentation helpers installed under
`~/.local/lib/`; workflow scripts retain their own actions and validation.
Short menus close after an action or cancellation and do not reopen their parent.

## Tracing a behavior

Start at the keybinding or Waybar module, follow the referenced command name to
its Home Manager module, then check whether that module installs a script or
declares a systemd service. Sway handles window arrangement, resize behavior,
and workspace back-and-forth directly. The sway-focus-urgent service listens for
window urgency events and focuses the requesting window, including hidden
scratchpad windows, without per-app launchers. Alt+Tab returns to the previously
focused workspace, while swayview provides the workspace overview on Mod+Tab.
