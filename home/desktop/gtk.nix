# Gruvbox GTK and icon themes with the existing Bibata cursor.
{ pkgs, ... }:

let
  iconTheme = import ./icon-theme.nix { inherit pkgs; };
in

{
  home.pointerCursor = {
    # Required since HM 25.11+ (missing it triggers a deprecation warning).
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "gruvbox-dark";
      package = pkgs.gruvbox-dark-gtk;
    };
    iconTheme = iconTheme;
    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = 1;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
