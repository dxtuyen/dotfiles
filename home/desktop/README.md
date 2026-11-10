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
- `fuzzel/`: application launcher, shared colors and menu presentation helper.
- `display/`: display temperature commands, menu and wlsunset service template.
- `screenshot/`: capture actions and their menu.
- `input/`: touchpad event toggle; Sway owns the actual input settings.
- `media/`: volume, microphone and brightness control notifications.
- `menus/`: utilities, session power actions and power profile selection.
- `network.nix`: wifui terminal window and advanced connection editor.
- `wallpaper/`: generated wallpaper images and the background service.

Shell behavior lives in `scripts/`; Nix declares dependencies and installs the
existing `~/.local/bin` entry points. `writeShellApplication` checks the packaged
commands with ShellCheck. Fuzzel menus source the helper installed by `fuzzel/`.

Initial popup geometry is defined in `windows/obsidian-popup.nix`: Obsidian
defaults to 70% × 85%, and Sway requests 60% × 75% for TickTick.
Subsequent window resizing and split layouts are owned by Sway.

## Popup and layout behavior

`Mod+B/V`, `Mod+S/W/E` and `Mod+Shift+Space` use native Sway commands.
Splitting a floating window creates a group inside that floating popup.

Application shortcuts use Sway's native scratchpad commands:

- Mod+O toggles Obsidian; Mod+I toggles TickTick.
- Mod+G toggles GoldenDict, preserving its Qt theme when launched.
- Mod+grave toggles the popup terminal.
- If no matching window exists, the same shortcut launches the application.
- Window rules assign popup marks and initial scratchpad placement.
- A visible popup on the current workspace is focused first; pressing again
  while it is focused hides it with `move scratchpad`, even after it has left
  the scratchpad through floating/tiling changes. A popup elsewhere is moved
  into the scratchpad and shown on the current workspace.
- Sway owns showing, hiding, focus, grouping and geometry. The helper checks
  command responses; it does not read the window tree,
  start Python or poll for new windows. Sway criteria select the focused window.
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

## Wi-Fi

The Waybar network icon and Utilities → Wi-Fi open `wifi-menu`, which runs
wifui in a floating Foot window with the NetworkManager backend. NetworkManager
continues to manage connections. Right-clicking the network icon opens
`nm-connection-editor` for advanced connection settings. No network applet is
autostarted.

wifui provides Vim-style navigation (`j`/`k`), search (`/`), saved networks
(`Tab`), connect/disconnect (`Enter`), forget (`f`), autoconnect (`a`) and Wi-Fi
sharing (`s`). Quit with `q` or `Esc`. Bluetooth and audio use Bluetui and WireMix.

`pkgs/wifui.nix` pins the upstream source and Cargo dependencies because wifui is
not available in the current Nixpkgs pin. To update it, change the revision and
version, refresh the source and Cargo hashes, then build `nix build .#wifui`
(the build also runs upstream unit tests, except one UI test that needs a live
Wi-Fi backend outside the sandbox). Keep connection handling upstream.

## Session power and Countdown

Edit `shared/session-policy.nix` to change the idle deadlines and sleep policy.
Without an idle inhibitor, displays turn off after 5 minutes without input, the
session locks after 10 minutes, and the machine sleeps after 15 minutes on
battery. AC power suppresses automatic sleep, including when connected after
the idle deadline. All three deadlines count from the last input. A manually
locked screen turns off after 10 seconds without input.

Idle sleep, the power menu's Suspend action, and closing an undocked lid use
`suspend-then-hibernate`. Systemd transitions to hibernation after one hour
asleep, or sooner on low battery. Explicit sleep and lid actions also work on
AC. The existing disk swap and resume configuration must work for hibernation;
zram alone cannot preserve a hibernation image.

`session/` owns screen power, locking and sleep. It honors standard logind idle
inhibitors and contains no Countdown commands or state checks. A successful
`swaylock.service` activates `session-locked.target`; that target stops when the
locker exits. Optional subscribers run after the target, which disables default
target ordering to avoid a dependency cycle. Failed locking never activates it.

`features/countdown/` owns all focus behavior:

- Running a session or enabling manual keep-awake starts its own
  `countdown-idle-inhibit.service`. The process holds a logind **idle-only**
  inhibitor, so the desktop's automatic deadlines are inhibited while explicit
  lock, sleep and lid actions remain available. Stop/crash/logout releases it.
- `countdown-lock-pause.service` subscribes to the confirmed-lock target and
  pauses the timer, preserving remaining time and clearing its manual
  keep-awake flag. It is reset on unlock for the next lock event.
- `countdown-sleep.service` independently observes logind sleep/wake events via
  Swayidle, with its own bounded sleep delay. It preserves the timer before
  sleep even if locking is slow. Lock and sleep handlers are idempotent and
  work in either order.
- Unlock and wake leave the timer paused; only an explicit resume restarts it
  and reacquires the inhibitor. The worker reconciles its own inhibitor after
  interrupted transitions or service restarts, without controlling Swayidle.

The worker watches state changes with inotify. A paused/empty session waits for
an event without polling; start/resume wakes it immediately. A running session
updates the clock every second and reconciles its inhibitor every five seconds.
Manual keep-awake without a running timer only needs the five-second health
check. Waybar renders read-only snapshots at startup and on signals, with no
background poll or nested service checks. Systemd restarts a failed worker;
worker startup refreshes Waybar and restores its state watch and inhibitor.

After rebuilding, log out/in once to start the new event subscribers together.
The automated tests use isolated state and do not lock or suspend the desktop;
test physical suspend/hibernate and resume separately on the laptop.

## Checks

Run `python3 -m unittest discover -s tests -v` from the repository root (requires
`inotifywait` for Countdown worker tests). Desktop
regression tests use temporary state and mocked commands; they do not change the
running desktop. Run `nix build .#checks.x86_64-linux.scripts --no-link` to build the
packaged commands and run their ShellCheck checks. Vocabulary integration is
owned by `home/features/vocabulary`, while application configuration is under
`home/programs`. The packaged script check also verifies the generated session
units and their dependency graph with `systemd-analyze` in an isolated home.
