# Architecture

The repository configures one NixOS laptop and its Home Manager environment.
Modules are grouped by what they own, not by implementation language.

```text
flake.nix                  pinned inputs, host output, packages and checks
hosts/laptop/              hardware and explicit system/user module composition
modules/nixos/             privileged services and system/hardware policy
shared/theme.nix           pure palette consumed by both system and user modules
home/
├── default.nix            explicit user module composition
├── packages.nix           standalone application/tool inventory and Flatpak apps
├── programs/              individual application configuration and its helpers
├── desktop/               compositor, graphical session and desktop controls
├── features/              workflows combining commands, applications or services
└── shell/                 interactive shell and command-line environment
tests/                     behavior tests with isolated state and mocked commands
pkgs/                      custom package derivations
```

## Ownership

- `programs` owns application-specific configuration, regardless of whether Home
  Manager supplies a ready-made option. Sioyek, Yazi, Btop and Neovim belong here.
- `desktop` owns Sway, session lock/idle/suspend, wallpaper, Rofi, screenshots,
  display/input/media controls and desktop window toggles.
- `features` owns workflows: Countdown, translation, scheduled trash cleanup,
  the training VM, and GoldenDict–Anki vocabulary integration.
- `shell` owns Bash setup and shell-specific tools. Code that changes the parent
  shell's state is sourced as shell initialization, not launched as a subprocess.
- Standalone applications can remain in `packages.nix`. Once an application or
  workflow needs configuration, its module owns the relevant package declarations.
- No separate `home/scripts` bucket exists: a script lives with the module that
  uses it. Shared runtime helpers have an explicit owner, such as Rofi's menu
  helper. NixOS modules never import data from the Home Manager layer.

## Files within a module

Small configuration-only modules stay a single `.nix` file. A module needing
runtime logic or assets follows this layout:

```text
feature/
├── default.nix            composition, packages, command packaging and services
├── config.nix             optional larger application configuration
├── services.nix           optional larger service definitions
├── scripts/               executable or sourced runtime logic (.sh, .py, ...)
└── assets/                static templates, CSS, images and other resources
```

Create optional files/directories only when needed. Neovim's existing native
configuration tree remains editable in its module so its live out-of-store links
and writable plugin lock remain intact.

Nix declares what is installed and configured. Shell/Python implement runtime
behavior. One-line wrappers and Nix build/activation glue can remain in Nix;
branches, retries, loops and state transitions belong in scripts. There is no
requirement to create one `.nix` wrapper per script.

Commands are packaged with `writeShellApplication`, declare their external tools
in `runtimeInputs`, and retain their `~/.local/bin` entry points. Packaging runs
ShellCheck. Existing workflows that explicitly handle nonzero exits keep their
original Bash error options rather than acquiring implicit `errexit` behavior.
Secrets and user data stay outside the repository.

## Integration and growth

- Imports are explicit, making enabled components reviewable in each `default.nix`.
- Desktop window rules and keybindings live under `desktop/sway`. Their shared
  feature values can be imported from the owning module, as with Obsidian geometry.
- Current session modules deliberately use Countdown; menus use the Rofi helper.
  All are enabled together. If features become independently optional, introduce
  module options and explicit dependencies before allowing separate disabling.
- Add another host under `hosts` when needed. Introduce profiles or enable options
  around actual host differences; keep package recipes independent under `pkgs`.
- Move repeated pure values shared by NixOS and Home Manager into `shared`.

## Validation

```bash
python3 -m unittest discover -s tests -v
nix fmt -- --check
nix flake check --no-build
nix build .#checks.x86_64-linux.workflows .#checks.x86_64-linux.scripts --no-link
```

CI runs formatting, evaluation, workflow tests and packaged-script checks on
pushes/PRs and manual dispatch. Tests avoid changing the running desktop; Nix
builds check packaged shell commands. Interactive session behavior still needs a
check after activating compositor/session changes.

Desktop module details and the wlsunset migration are in
[`home/desktop/README.md`](../home/desktop/README.md).
