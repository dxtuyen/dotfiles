{ pkgs, ... }:

let
  countdownEngine = pkgs.writeTextFile {
    name = "countdown-engine";
    executable = true;
    text =
      builtins.replaceStrings [ "@flock@" "@jq@" ] [ "${pkgs.util-linux}/bin/flock" "${pkgs.jq}/bin/jq" ]
        (builtins.readFile ./countdown-engine.sh);
  };
  countdownMenu = pkgs.writeTextFile {
    name = "countdown-menu";
    executable = true;
    text = builtins.readFile ./countdown-menu.sh;
  };
in
{
  imports = [ ./services.nix ];

  home.file = {
    ".local/bin/countdown-engine" = {
      executable = true;
      source = countdownEngine;
    };
    ".local/bin/countdown".source = countdownMenu;
  };
}
