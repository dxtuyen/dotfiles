# Papirus keeps its broad application-icon coverage; the warm yellow folder
# variant uses the closest supported accent to Gruvbox's muted yellow.
{ pkgs }:

pkgs.papirus-icon-theme.override {
  color = "yellow";
}
