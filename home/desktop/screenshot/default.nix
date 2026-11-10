{ pkgs, ... }:

let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/screenshot.sh;
  };
  screenshotMenu = pkgs.writeShellApplication {
    name = "screenshot-menu";
    runtimeInputs = [ pkgs.tofi ];
    extraShellCheckFlags = [ "--external-sources" ];
    text =
      builtins.replaceStrings
        [ "# shellcheck source=../../tofi/scripts/menu.sh" ]
        [ "# shellcheck source=${../tofi/scripts/menu.sh}" ]
        (builtins.readFile ./scripts/screenshot-menu.sh);
  };
in
{
  home.packages = [
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
  ];
  # screenshot creates the destination directory only when saving a capture.
  home.file = {
    ".local/bin/screenshot".source = "${screenshot}/bin/screenshot";
    ".local/bin/screenshot-menu".source = "${screenshotMenu}/bin/screenshot-menu";
  };
}
