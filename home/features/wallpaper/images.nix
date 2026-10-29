{
  pkgs,
  inputs,
  wallpaperResolution ? { },
}:

let
  theme = import ../../theme.nix;
  generator = pkgs.callPackage "${inputs.nix-wallpaper}/pkg" { };
  settings = {
    width = wallpaperResolution.width or 1920;
    height = wallpaperResolution.height or 1080;
    logoSize = 44.25;
    backgroundColor = theme.bg0;
  };
in
{
  desktop = generator.override (
    settings
    // {
      logoColors = {
        color0 = theme.orange;
        color1 = theme.yellow;
        color2 = theme.green;
        color3 = theme.blue;
        color4 = theme.purple;
        color5 = theme.red;
      };
    }
  );

  lockscreen = generator.override (
    settings
    // {
      logoColors = {
        color0 = theme.blue;
        color1 = theme.blueDim;
        color2 = theme.blue;
        color3 = theme.blueDim;
        color4 = theme.blue;
        color5 = theme.blueDim;
      };
    }
  );
}
