{ pkgs, ... }:

let
  mediaNotify = pkgs.writeShellApplication {
    name = "media-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.gawk
      pkgs.wireplumber
      pkgs.brightnessctl
      pkgs.libnotify
    ];
    text =
      builtins.replaceStrings
        [ "@flock@" "@timeout@" ]
        [ "${pkgs.util-linux}/bin/flock" "${pkgs.coreutils}/bin/timeout" ]
        (builtins.readFile ./scripts/media-notify.sh);
  };
in
{
  home.packages = [
    pkgs.brightnessctl
    pkgs.libnotify
  ];
  home.file.".local/bin/media-notify".source = "${mediaNotify}/bin/media-notify";
}
