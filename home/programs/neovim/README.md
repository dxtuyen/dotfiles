# LazyVim

LazyVim uses the [official starter](https://github.com/LazyVim/starter). Local
changes add Gruvbox Material and use Nix-provided language tools.

## Ownership

- `../neovim.nix` installs Neovim and external tools, generates `init.lua`, and
  links the editable configuration into `~/.config/nvim`.
- `lua/config/` contains the starter bootstrap and local editor settings.
- `lua/plugins/` contains plugin overrides. `colorscheme.lua` matches the
  Gruvbox Material settings in `../../theme.nix`; `tools.lua` uses Nix tools
  instead of Mason downloads.
- `lazyvim.json` records Extras; `lazy-lock.json` records plugin versions. Both
  are writable links to this checkout and should be committed after changes.
- Downloaded plugins, parsers, logs, undo files and caches stay in Neovim's
  normal XDG data/state/cache directories, outside this repository.

The links assume the checkout is at `~/dotfiles`, like the system's existing
rebuild aliases. Update `nvimConfig` in `../neovim.nix` if the checkout moves.
Existing files elsewhere under `~/.config/nvim` are preserved.

## Apply and maintain

From the repository root, include new files in Git before rebuilding a Git flake:

```bash
git add home/programs/neovim.nix home/programs/neovim home/programs/tmux.nix home/programs/default.nix
sudo nixos-rebuild switch --flake .#laptop
nvim
```

The first launch downloads plugins and builds Tree-sitter parsers, so it needs
network access. Run `:LazyHealth` afterwards. Use `:checkhealth vim.lsp` and
`:ConformInfo` to inspect language servers and formatters.

Edits under `lua/` take effect after restarting Neovim. Changes to `init.lua`
or the Nix package list require a rebuild. Keep the default LazyVim keymaps;
press Space to discover commands with which-key.

Baseline language support is Nix (`nil`, `nixfmt`, `statix`), Lua
(`lua-language-server`, `stylua`) and Bash (`bash-language-server`, `shfmt`,
`shellcheck`). Bash's language server uses ShellCheck for diagnostics. Other
languages can be enabled through `:LazyExtras`; install their external tools
with Nix in `programs.neovim.extraPackages` (or a project's development shell).
Mason is disabled, so enabling an Extra does not install its tools automatically.
LuaRocks support is disabled because the baseline plugins do not require it.
Plugins that need Lua modules require an explicit dependency setup.

Use `:Lazy` to update plugins, then review and commit the changed lockfile. To
return to committed plugin versions, restore `lazy-lock.json` from Git and run
`:Lazy restore`. A NixOS generation rollback restores Nix packages and generated
files; it does not restore this editable Lua configuration or downloaded plugins.

Foot and LazyVim use Gruvbox Material with the existing Nerd Font. Wayland
clipboard access uses the installed `wl-clipboard`. Sway uses Super for desktop
navigation, tmux uses Ctrl+b followed by h/j/k/l, and LazyVim uses Ctrl+h/j/k/l
for editor windows. The `nt` shell helper opens a tmux window in the current
directory when inside tmux.

The adapted starter files retain the upstream Apache-2.0 license in `LICENSE`.
