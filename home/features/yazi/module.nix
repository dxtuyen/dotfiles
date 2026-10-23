# Yazi runs in Foot; Mod+y opens its popup.
{ pkgs, ... }:

{
  home.packages = [ pkgs.yazi ];

  xdg.configFile = {
    "yazi/yazi.toml".source = ./yazi.toml;
    "yazi/keymap.toml".source = ./keymap.toml;
    "yazi/theme.toml".source = ./theme.toml;
    "yazi/gruvbox-dark.tmTheme".source = ./gruvbox-dark.tmTheme;
  };

  xdg.configFile."yazi/plugins/smart-enter.yazi".source = pkgs.yaziPlugins.smart-enter;
}
