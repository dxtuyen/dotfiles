# Gruvbox Material: dark background, medium contrast, material foreground.
# https://github.com/sainnhe/gruvbox-material/blob/master/autoload/gruvbox_material.vim
# Surface/foreground aliases use steps from the upstream palette so desktop
# applications can share colors without each maintaining separate hex values.
rec {
  bgDim = "#1b1b1b";
  bg0 = "#282828";
  bg1 = "#32302f";
  bg2 = "#3c3836";
  bg3 = "#45403d";
  bg4 = "#5a524c";
  fg0 = "#ddc7a1";
  fg1 = "#d4be98";
  fg2 = fg1;
  fg3 = "#a89984";
  fg4 = gray;
  gray = "#928374";
  muted = "#7c6f64";
  red = "#ea6962";
  green = "#a9b665";
  yellow = "#d8a657";
  blue = "#7daea3";
  blueDim = "#458588"; # Darker blue for the two-tone lockscreen logo.
  purple = "#d3869b";
  aqua = "#89b482";
  orange = "#e78a4e";
  splitIndicator = "#c5a87c";
  selection = "#45403d";
  selectionBlue = "#374141";

  # Material uses the same accents in normal and bright ANSI slots.
  ansi = [
    bg0
    red
    green
    yellow
    blue
    purple
    aqua
    fg1
    gray
    red
    green
    yellow
    blue
    purple
    aqua
    fg0
  ];
}
