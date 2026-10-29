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
  countdownSleepWatch = pkgs.writeTextFile {
    name = "countdown-sleep-watch";
    executable = true;
    text = builtins.readFile ./countdown-sleep-watch.sh;
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
    ".local/bin/countdown-sleep-watch".source = countdownSleepWatch;
  };
}
