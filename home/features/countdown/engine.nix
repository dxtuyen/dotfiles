{ pkgs, ... }:

let
  countdownEngine = pkgs.writeTextFile {
    name = "countdown-engine";
    executable = true;
    text = builtins.replaceStrings [ "@flock@" ] [ "${pkgs.util-linux}/bin/flock" ] (
      builtins.readFile ./countdown-engine.sh
    );
  };
in
{
  home.file.".local/bin/countdown-engine" = {
    executable = true;
    source = countdownEngine;
  };
}
