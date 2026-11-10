{ pkgs, ... }:

let
  theme = import ../../../shared/theme.nix;
in
{
  programs.tofi = {
    enable = true;
    settings = {
      # A font file avoids Fontconfig lookup at startup; Nerd Font glyphs
      # still work in the utility menus without application icon support.
      font = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
      font-size = 12;
      width = 640;
      height = 340;
      num-results = 8;
      outline-width = 0;
      border-width = 1;
      corner-radius = 6;
      padding-top = 12;
      padding-bottom = 12;
      padding-left = 16;
      padding-right = 16;
      result-spacing = 10;
      background-color = theme.bg0;
      text-color = theme.fg1;
      border-color = theme.fg3;
      prompt-color = theme.fg3;
      placeholder-color = theme.fg3;
      selection-color = theme.fg0;
      selection-match-color = theme.aqua;
      selection-background = theme.selection;
      prompt-text = "❯ ";
      placeholder-text = "Search applications…";
      text-cursor = true;
      history = true;
      fuzzy-match = true;
      drun-launch = true;
    };
  };

  # Tofi's direct launcher uses GIO for Terminal=true desktop entries.
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "foot.desktop" ];
  };
  home.file.".local/lib/menu.sh".source = ./scripts/menu.sh;
}
