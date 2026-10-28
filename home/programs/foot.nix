# Foot — Gruvbox Material, native Wayland. SIXEL lets Yazi show image previews.
#
# ⚠️ COLOR SYNTAX: single = `RRGGBB` (6 hex digits, NO `#`); pairs (cursor, jump-labels,
# scrollback-indicator, search-box-*) = TWO hex colors separated by WHITESPACE, order is
# `text-color background-color`. On a syntax error foot prints `err: config.c:...`;
# verify with `foot -C` without opening a window.
{ pkgs, ... }:

let
  theme = import ../theme.nix;
  hex = color: builtins.substring 1 6 color;
  # Medium Material port linked by sainnhe's Related Projects wiki.
  upstreamTheme = pkgs.fetchurl {
    url = "https://gist.githubusercontent.com/rehanzo/71f882adb28b7870b6643cd9eb0e944a/raw/beeee61fd669355729bd8c32f126d108679d8884/gruvbox-material-foot";
    hash = "sha256-UAw3LRTUMYvQsdU94HyCE196Eix7MrPBVbH6h/VZFH4=";
  };
  materialTheme = pkgs.runCommand "foot-gruvbox-material.ini" { } ''
    # Foot 1.28 renamed the legacy [colors] section.
    sed 's/^\[colors\]$/[colors-dark]/' ${upstreamTheme} > "$out"
  '';
in

{
  programs.foot = {
    enable = true;

    # Generates $XDG_CONFIG_HOME/foot/foot.ini.
    settings = {
      main = {
        include = "${materialTheme}";
        font = "JetBrainsMono Nerd Font:size=12";
        pad = "14x10";
      };

      scrollback.lines = 10000;

      mouse.hide-when-typing = "yes";

      # Open a new window with `nt`; do not use the default spawn-terminal key.
      "key-bindings".spawn-terminal = "none";

      cursor = {
        style = "beam";
        blink = "yes";
        blink-rate = 550;
        beam-thickness = 1.5;
      };

      # Keep the upstream palette; only UI affordances need local overrides.
      colors-dark = {
        # Opaque background keeps text and file previews clear against the wallpaper.
        alpha = 1.0;
        cursor = "${hex theme.bg0} ${hex theme.fg3}";
        "selection-foreground" = hex theme.fg1;
        "selection-background" = hex theme.selection;

        # All are "text background" pairs.
        "jump-labels" = "${hex theme.bg0} ${hex theme.orange}";
        "scrollback-indicator" = "${hex theme.bg0} ${hex theme.blue}";
        "search-box-match" = "${hex theme.bg0} ${hex theme.blue}";
        "search-box-no-match" = "${hex theme.bg0} ${hex theme.red}";
      };
    };
  };
}
