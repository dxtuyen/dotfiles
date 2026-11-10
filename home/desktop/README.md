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

Application shortcuts use Sway's native `scratchpad show` behavior:

- Mod+O toggles Obsidian; Mod+I toggles TickTick.
- Mod+G toggles GoldenDict, preserving its Qt theme when launched.
- Mod+grave toggles the popup terminal.
- If no matching window exists, the same shortcut launches the application.
- Window rules assign popup marks and initial scratchpad placement.
- Sway owns showing, hiding, focus, grouping and geometry. The helper sends a
  toggle command and checks its response; it does not read the window tree,
  start Python, poll for new windows or implement custom focus selection.
- Shortcuts suppress automatic key repeats. There is no startup waiting lock;
  repeated manual presses before a window appears can request another launch.

After applying the configuration, reopen existing popup windows so the new
window rules assign their marks. Headless Sway tests exercise native toggles.

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
