{ lib, pkgs, ... }:

let
  theme = import ../theme.nix;
  iconTheme = import ./icon-theme.nix { inherit pkgs; };
  # QPalette roles, in Qt order (WindowText through PlaceholderText).
  # Fusion consumes this palette directly; no extra style engine is needed.
  colors = text: [
    text
    theme.bg1
    theme.bg4
    theme.bg3
    theme.bgDim
    theme.bg2
    text
    theme.fg0
    text
    theme.bg0
    theme.bg0
    theme.bgDim
    theme.selection
    theme.fg0
    theme.blue
    theme.purple
    theme.bg1
    theme.bgDim
    theme.bg1
    theme.fg1
    theme.gray
  ];
  colorList = text: lib.concatStringsSep ", " (colors text);
  scheme = pkgs.writeText "gruvbox-material-qt.conf" ''
    [ColorScheme]
    active_colors=${colorList theme.fg1}
    inactive_colors=${colorList theme.fg1}
    disabled_colors=${colorList theme.gray}
  '';
  settings = {
    Fonts = {
      general = ''"Noto Sans,11"'';
      fixed = ''"JetBrains Mono,11"'';
    };
    Appearance = {
      style = "Fusion";
      icon_theme = iconTheme.name;
      custom_palette = true;
      color_scheme_path = "${scheme}";
    };
  };
in
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "Fusion";
    qt5ctSettings = settings;
    qt6ctSettings = settings;
  };
}
