# Configuration notes

Commands run from the repository root. The system target is `laptop`; rebuilding also applies Home Manager.

## Where to make changes

| Setting | Source |
| --- | --- |
| Flake inputs, target, and username | [flake.nix](../flake.nix) |
| Host imports and hardware | [hosts/laptop/](../hosts/laptop/) |
| Boot, networking, hardware, and system services | [modules/nixos/](../modules/nixos/) |
| User packages and application settings | [packages.nix](../home/packages.nix), [programs/](../home/programs/) |
| Window rules and keyboard shortcuts | [sway.nix](../home/desktop/sway.nix) |
| Status bar and notifications | [waybar.nix](../home/desktop/waybar.nix), [mako.nix](../home/desktop/mako.nix) |
| Default applications | [mimeapps.nix](../home/desktop/mimeapps.nix) |
| Colors and toolkit appearance | [theme.nix](../home/theme.nix), [gtk.nix](../home/desktop/gtk.nix), [qt.nix](../home/desktop/qt.nix) |
| Workflows and user commands | [features/](../home/features/), [scripts/](../home/scripts/) |
| Bash helpers and shell tools | [shell/](../home/shell/) |

The host imports NixOS modules and [home/default.nix](../home/default.nix). Keep system settings under `modules/nixos/` and user settings under `home/`. Longer scripts live beside their Nix installation modules.

## Desktop essentials

`Super` is the Windows/logo key. The complete bindings are in `sway.nix` above.

| Shortcut | Action |
| --- | --- |
| `Super+Enter` / `Super+D` | Open a terminal / application launcher |
| `` Super+` `` | Toggle the popup terminal |
| `Super+1…9`, `Super+0` | Switch to workspace 1–10; add `Shift` to move a window |
| `Super+H/J/K/L` or `Super+Arrow` | Focus by direction; add `Shift` to move a window |
| `Alt+Tab` / `Super+Tab` | Previously focused window / workspace overview |
| `Super+[` / `Super+]` | Previous / next workspace; add `Shift` to move a window |
| `Super+F` / `Super+Shift+Space` | Toggle fullscreen / floating mode |
| `Super+-` / `Super+Shift+-` | Show scratchpad / send a window to it |
| `Super+C` | Countdown |
| `Super+U` / `Super+P` | Utilities / power menu |
| `Super+Esc` / `Super+Shift+C` | Lock / reload Sway |
| `Print` / `Alt+Print` | Copy a selected region / full screen; use `Shift+Print` / `Ctrl+Print` to save |
| `Super+T` / `Super+Shift+T` / `Super+Ctrl+T` | Translate to English / Vietnamese / proofread English |

`Alt+Tab` returns to the previously focused window across workspaces, skipping hidden scratchpad windows. The existing `sway-focus-urgent` service also records focus history in the session runtime directory; no separate switcher daemon is needed. Scratchpads can be shown manually with their existing shortcuts.

Countdown inhibits automatic locking and idle suspend while running. Locking pauses it and clears manual idle inhibition; resume Countdown manually after unlocking or waking. Unlocking does not restore the old manual inhibition setting. The lock is confirmed before changing Countdown or inhibition state.

The idle policy lives in [`home/desktop/session.nix`](../home/desktop/session.nix):

| Condition | Behavior |
| --- | --- |
| No activity for 5 minutes | Lock the session |
| Lock manually while idle inhibition is on | Turn inhibition off and pause Countdown; automatic idle handling resumes |
| Locked, then inactive for 10 seconds | Turn displays off; input turns them on for authentication |
| No activity for 15 minutes, on battery | Request suspend |
| No activity for 15 minutes, external power connected | Keep running with the screen locked/off; recheck power every 30 seconds |
| Input, idle inhibition, or logout | Cancel pending idle power checks |
| Wake from sleep | Turn displays on and give active idle handling a fresh deadline; keep Countdown paused |
| Close the lid | Suspend even on external power; ignore when docked |

External power takes precedence over a battery reporting discharge; peripheral power supplies are ignored. `session-lock` is the single sleep/wake listener, independent of Countdown inhibition. `locked-display` follows the lifetime of `swaylock.service`, so unlocking also stops its display timeout. Physical sleep and charging behavior still need a hardware check after activation.

Quick Lang reads the selection or clipboard and requires a Gemini key at `${XDG_CONFIG_HOME:-$HOME/.config}/quick-lang/api.key`. It sends the text to the service and copies the result to the clipboard. Screenshots are saved under `~/Pictures/Screenshots/`.

PDFs open in Sioyek; `F8` toggles custom page colors. In Bash, `y` opens Yazi and follows its last directory on exit; `nt` opens a terminal or tmux window in the current directory.

Neovim uses LazyVim with Gruvbox Material. Nix manages the editor and language
tools; editable Lua, Extras and plugin versions live in
[`home/programs/neovim/`](../home/programs/neovim/README.md). After the first
launch, run `:LazyHealth`. In tmux, use `Ctrl+b` followed by `h/j/k/l` to select
panes; LazyVim keeps `Ctrl+h/j/k/l` for editor windows.

Yazi adds application choices only for PDF, HTML, and CSV files. For these files, `Enter` uses the system default and the built-in `Shift+O` opens the application menu; other file types keep Yazi's defaults. Menu choices affect only that launch. Change the default browser in the browser's settings. Choices are saved in the writable `~/.config/mimeapps.list`; Nix supplies lower-priority defaults in `~/.local/share/applications/mimeapps.list`, so rebuilds preserve your choices.

Media keys adjust volume by 5% within 0–100% and screen brightness by 10%, with a 5% minimum. Volume down mutes at zero. Volume up restores a manually muted level, or raises zero to 5% and unmutes. Speaker and microphone mute keys toggle once per press without changing the selected level.

## Maintenance

### Build and validate

```bash
nix fmt -- --check
nix flake check --no-build
nixos-rebuild build --flake .#laptop
sudo nixos-rebuild switch --flake .#laptop
```

Use `nix fmt` to fix formatting. Pushes and pull requests run only formatting and flake evaluation in CI. Git pushes do not run local checks.

When changing desktop scripts, run the optional regression suite locally:

```bash
nix build .#checks.x86_64-linux.workflows --no-link --print-build-logs
```

You can also run the suite in GitHub Actions by selecting **Nix checks → Run workflow**. It uses isolated state and command stubs, so verify affected desktop and hardware behavior manually.

`nswitch` uses `~/dotfiles` and the current hostname; `nh os switch` uses the path in `modules/nixos/core.nix`. Reload Sway after activation for compositor changes, log in again for session environment changes, and reboot for a new kernel.

### Update and roll back

```bash
nix flake update
git diff -- flake.lock
```

Review the changes, then validate and build before activation. For selected inputs, use `nix flake update nixpkgs home-manager`. Keep `system.stateVersion` and `home.stateVersion` unchanged during routine updates.

To activate the previous system generation:

```bash
sudo nixos-rebuild switch --rollback
```

If boot fails, select an older generation in systemd-boot. Fix or revert the source changes before rebuilding again. Rollback does not restore personal files or application data.

### Cleanup and logs

Nix garbage collection runs weekly with a seven-day retention policy. The optional [generation-reset script](../home/shell/scripts/reset-generations.sh) removes older system generations and keeps the previously running configuration as generation 1; use it only when intentionally resetting history. The GIO trash is cleaned daily of entries older than 30 days.

Start troubleshooting with failed units and the relevant journal:

```bash
systemctl --user --failed
journalctl -b -u greetd
journalctl --user -b -u swayidle -u session-lock -u locked-display -u idle-suspend -u countdown-engine
```

For a specific unit, use `systemctl --user status UNIT` and `journalctl --user -b -u UNIT`. For hibernation problems, compare `swapon --show`, `lsblk -f`, and the `resume=` argument in `/proc/cmdline`.

## Adapt to another machine

1. Regenerate `hosts/laptop/hardware-configuration.nix` on the target and verify its filesystems and swap devices.
2. Review `userName` and the target in `flake.nix`, plus the hostname and imports in `hosts/laptop/default.nix`.
3. Check `modules/nixos/laptop.nix` for Intel graphics, resume, sleep, lid handling, and battery settings. Review packages, Git identity, and personal paths under `home/`.
4. Use `~/dotfiles`, or update the `nh` path and `nswitch` alias to match the checkout location. Build and validate before activation.

Keep credentials and mutable application data outside Git and back them up separately.

## Feature notes

- [Wallpapers](../home/features/wallpaper/README.md): resolution, standalone builds, and attribution.
- [Anki templates and styles](../home/assets/anki/README.md): apply the Longman vocabulary templates or Yanki CSS.
- [LazyVim](../home/programs/neovim/README.md): editor structure, language tools, and plugin updates.
