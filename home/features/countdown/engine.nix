{ pkgs, ... }:

let
  countdownEngine = pkgs.writeTextFile {
    name = "countdown-engine";
    executable = true;
    text =
      builtins.replaceStrings [ "@flock@" "@jq@" ] [ "${pkgs.util-linux}/bin/flock" "${pkgs.jq}/bin/jq" ]
        (builtins.readFile ./countdown-engine.sh);
  };
in
{
  home.file.".local/bin/countdown-engine" = {
    executable = true;
    source = countdownEngine;
  };
}
