# Desktop modules

`default.nix` explicitly imports the desktop's modules. Small configuration-only
modules remain individual `.nix` files. Features with scripts use this layout:

```text
feature/
├── default.nix
└── scripts/
    └── command.sh
```

Each module owns its configuration, command packaging and related services:

- `sway/`: compositor configuration, shortcuts, window rules and focus watcher.
- `windows/`: Obsidian, TickTick and popup terminal toggles; shared Obsidian geometry.
- `session/`: lock, idle, suspend, resume and session refresh commands/services.
- `rofi/`: Rofi themes and the shared menu presentation helper.
- `display/`: display temperature commands, menu and wlsunset service template.
- `screenshot/`: capture actions and their menu.
- `input/`: touchpad event toggle; Sway owns the actual input settings.
- `media/`: volume, microphone and brightness control notifications.
- `menus/`: utilities, session power actions and power profile selection.
- `wallpaper/`: generated wallpaper images and the background service.

Shell behavior lives in `scripts/`; Nix declares dependencies and installs the
existing `~/.local/bin` entry points. `writeShellApplication` checks the packaged
commands with ShellCheck. Rofi menus source the helper installed by `rofi/`.

Initial popup geometry is defined in `windows/obsidian-popup.nix`: Obsidian
defaults to 70% × 85%, and Sway requests 60% × 75% for TickTick.
Subsequent window resizing and split layouts are owned by Sway.

## Popup and layout behavior

`Mod+B/V`, `Mod+S/W/E` and `Mod+Shift+Space` use native Sway commands.
Splitting a floating window creates a group inside that floating popup.

`sway-popup` handles application toggles:

- Mod+O hides/shows the entire floating group containing Obsidian.
- Mod+I launches TickTick Flatpak or hides/shows its floating window group without quitting it.
- Mod+G uses the same toggle for GoldenDict, with its Qt theme environment preserved.
- Mod+grave hides/shows the entire floating group containing the popup terminal.
- A visible unfocused popup is focused first; only a focused popup group is hidden.
- Popups on another workspace are recalled to the current workspace and focused.
- Split children stay together, including when recalled to another workspace.
- Group geometry is left to Sway; the script never resizes or detaches members.
- Before launching an absent popup, focus moves up to the workspace so its first
  window starts separately from the existing floating split.
- Repeated presses during startup are ignored until the window appears.

The script only finds the popup group, toggles it, or launches a new popup.
There is no custom tiling behavior or saved geometry state. Headless Sway tests
cover both grouped toggles and independent popup launches.

## Display temperature

`wlsunset-apply` serializes changes, stops the managed mode instances, starts
`wlsunset@MODE.service` and checks that it stays active during an initial startup
check. Only then does it atomically save an explicit selection to
`${XDG_STATE_HOME:-~/.local/state}/wlsunset-mode`. This confirms startup, not future
process health. The menu queries systemd for the active mode.

Sway starts the saved mode when the session starts. The service stops with
`sway-session.target`; reloads restore the preference through `refresh-session`.
Logs remain available through `journalctl --user -u 'wlsunset@*'`.

When migrating from the previous unmanaged background process, rebuild and log
out/in once so the old process exits before the managed instance starts.

## Checks

Run `python3 -m unittest discover -s tests -v` from the repository root. Desktop
regression tests use temporary state and mocked commands; they do not change the
running desktop. Run `nix build .#checks.x86_64-linux.scripts --no-link` to build the
packaged commands and run their ShellCheck checks. Vocabulary integration is
owned by `home/features/vocabulary`, while application configuration is under
`home/programs`.
