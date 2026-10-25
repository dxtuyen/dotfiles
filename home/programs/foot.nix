# Foot — Gruvbox Dark, native Wayland. SIXEL support lets Yazi show image previews.
#
# ⚠️ COLOR SYNTAX: single = `RRGGBB` (6 hex digits, NO `#`); pairs (cursor, jump-labels,
# scrollback-indicator, search-box-*) = TWO hex colors separated by WHITESPACE, order is
# `text-color background-color`. On a syntax error foot prints `err: config.c:...`;
# verify with `foot -C` without opening a window.
{ ... }:

let
  theme = import ../theme.nix;
  hex = color: builtins.substring 1 6 color;
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

      # Declare only the 16 ANSI colors + background/foreground/cursor; the 256-color
      # table (term-colors 16-255) keeps foot's defaults. Add more here if wanted.
      colors-dark = {
        # Opaque background keeps text and file previews clear against the wallpaper.
        alpha = 1.0;
        background = hex theme.bg0;
        foreground = hex theme.fg1;
        cursor = "${hex theme.bg0} ${hex theme.blue}";
        "selection-foreground" = hex theme.fg1;
        "selection-background" = hex theme.bg2;

        # ANSI 0-7 (Gruvbox standard/neutral palette)
        regular0 = hex theme.bg0;
        regular1 = hex theme.neutralRed;
        regular2 = hex theme.neutralGreen;
        regular3 = hex theme.neutralYellow;
        regular4 = hex theme.neutralBlue;
        regular5 = hex theme.neutralPurple;
        regular6 = hex theme.neutralAqua;
        regular7 = hex theme.fg4;

        # ANSI 8-15 (Gruvbox bright palette)
        bright0 = hex theme.gray;
        bright1 = hex theme.red;
        bright2 = hex theme.green;
        bright3 = hex theme.yellow;
        bright4 = hex theme.blue;
        bright5 = hex theme.purple;
        bright6 = hex theme.aqua;
        bright7 = hex theme.fg1;

        # All are "text background" pairs.
        "jump-labels" = "${hex theme.bg0} ${hex theme.orange}";
        "scrollback-indicator" = "${hex theme.bg0} ${hex theme.blue}";
        "search-box-match" = "${hex theme.bg0} ${hex theme.blue}";
        "search-box-no-match" = "${hex theme.bg0} ${hex theme.red}";
      };
    };
  };
}
