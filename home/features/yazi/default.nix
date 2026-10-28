# Rofi launches Yazi in a regular tiled Foot window.
{ pkgs, ... }:

let
  # Ready-made Material flavor listed in yazi-rs/flavors, pinned for Nix.
  # https://github.com/matt-dong-123/gruvbox-material.yazi
  materialFlavor = pkgs.fetchFromGitHub {
    owner = "matt-dong-123";
    repo = "gruvbox-material.yazi";
    rev = "e0fd2d800aeb6adb680496b1a5ef125b901b7413";
    hash = "sha256-mfIdFIe++jRDbTQBcLlpAq91JzmgL2SvqPxkYuCnKdQ=";
  };
in
{
  home.packages = [ pkgs.yazi ];

  xdg.desktopEntries.yazi = {
    name = "Yazi";
    genericName = "Terminal File Manager";
    exec = "${pkgs.foot}/bin/foot --app-id=yazi -e yazi";
    terminal = false;
    categories = [
      "System"
      "FileTools"
    ];
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = ./yazi.toml;
    "yazi/keymap.toml".source = ./keymap.toml;
    "yazi/theme.toml".text = ''
      [flavor]
      dark = "gruvbox-material"
    '';
    "yazi/flavors/gruvbox-material.yazi".source = materialFlavor;
    "yazi/plugins/smart-enter.yazi".source = pkgs.yaziPlugins.smart-enter;
  };
}
