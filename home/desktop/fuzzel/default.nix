{ pkgs, ... }:

let
  theme = import ../../../shared/theme.nix;
  iconTheme = import ../icon-theme.nix { inherit pkgs; };
  rgba = color: builtins.substring 1 6 color + "ff";
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12,Font Awesome 7 Free:size=12";
        icon-theme = iconTheme.name;
        terminal = "${pkgs.foot}/bin/foot";
        # Keep the menu open when focus moves away; right-click or Esc closes it.
        exit-on-keyboard-focus-loss = false;
        prompt = "❯ ";
        placeholder = "Search applications…";
        width = 42;
        lines = 8;
        horizontal-pad = 16;
        vertical-pad = 12;
        inner-pad = 10;
      };
      colors = {
        background = rgba theme.bg0;
        text = rgba theme.fg1;
        prompt = rgba theme.fg3;
        placeholder = rgba theme.fg3;
        message = rgba theme.fg3;
        input = rgba theme.fg1;
        match = rgba theme.aqua;
        selection = rgba theme.selection;
        selection-text = rgba theme.fg0;
        selection-match = rgba theme.aqua;
        border = rgba theme.fg3;
      };
      border = {
        width = 1;
        radius = 6;
      };
      # Menus accept only listed actions; text prompts still accept Enter.
      key-bindings.execute-input = "none";
    };
  };

  home.file.".local/lib/menu.sh".source = ./scripts/menu.sh;
}
