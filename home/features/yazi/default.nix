# Rofi launches Yazi in a regular tiled Foot window.
{ pkgs, ... }:

let
  # Upstream Gruvbox Dark flavor, pinned for reproducible Home Manager builds.
  # https://github.com/bennyyip/gruvbox-dark.yazi
  gruvboxDarkFlavor = pkgs.fetchFromGitHub {
    owner = "bennyyip";
    repo = "gruvbox-dark.yazi";
    rev = "71b03f6a382188a37e76d9e0b94332ee7146ea9c";
    hash = "sha256-ctGclLIOVQIXSM+8RJL43hEx1C7ecxAgjPs7BzZHo4A=";
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
      dark = "gruvbox-dark"
    '';
    "yazi/flavors/gruvbox-dark.yazi".source = gruvboxDarkFlavor;
    "yazi/plugins/smart-enter.yazi".source = pkgs.yaziPlugins.smart-enter;
  };
}
