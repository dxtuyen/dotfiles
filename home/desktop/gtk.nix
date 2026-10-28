# Gruvbox Material GTK 3/4 with the existing icons and Bibata cursor.
{ pkgs, ... }:

let
  iconTheme = import ./icon-theme.nix { inherit pkgs; };
  gtkTheme = {
    name = "Gruvbox-Dark-Medium";
    package = pkgs.gruvbox-gtk-theme.override {
      colorVariants = [ "dark" ];
      sizeVariants = [ "standard" ];
      themeVariants = [ "default" ];
      tweakVariants = [ "medium" ];
    };
  };
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
    theme = gtkTheme;
    # HM 26.05+ no longer inherits the GTK 3 theme for GTK 4. Import its
    # stylesheet explicitly so libadwaita apps such as Foliate match as well.
    gtk4.theme = gtkTheme;
    colorScheme = "dark";
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
