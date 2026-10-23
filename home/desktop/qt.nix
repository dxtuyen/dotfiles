{ ... }:

{
  # GoldenDict-NG is a Qt 6 app. GTK's dark preference does not theme Qt,
  # so give Qt apps a dark widget style and the same icon theme as GTK/Mako.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "adwaita-dark";

    qt6ctSettings.Appearance.icon_theme = "Gruvbox-Plus-Dark";
  };
}
