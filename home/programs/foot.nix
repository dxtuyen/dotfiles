# Foot — Gruvbox Material, native Wayland. SIXEL lets Yazi show image previews.
#
# ⚠️ COLOR SYNTAX: single = `RRGGBB` (6 hex digits, NO `#`); pairs (cursor, jump-labels,
# scrollback-indicator, search-box-*) = TWO hex colors separated by WHITESPACE, order is
# `text-color background-color`. On a syntax error foot prints `err: config.c:...`;
# verify with `foot -C` without opening a window.
{ lib, ... }:

let
  theme = import ../theme.nix;
  hex = color: builtins.substring 1 6 color;
  # Foot names ANSI slots 0–7 regular0–7 and slots 8–15 bright0–7.
  ansiColors = builtins.listToAttrs (
    lib.imap0 (index: color: {
      name = if index < 8 then "regular${toString index}" else "bright${toString (index - 8)}";
      value = hex color;
    }) theme.ansi
  );
in

{
  programs.foot = {
    enable = true;

    # Generates $XDG_CONFIG_HOME/foot/foot.ini.
    settings = {
      main = {
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

      colors-dark = ansiColors // {
        background = hex theme.bg0;
        foreground = hex theme.fg1;
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
