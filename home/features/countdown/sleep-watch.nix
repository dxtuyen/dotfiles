{ pkgs, ... }:

let
  countdownSleepWatch = pkgs.writeTextFile {
    name = "countdown-sleep-watch";
    executable = true;
    text = builtins.readFile ./countdown-sleep-watch.sh;
  };
in
{
  home.file.".local/bin/countdown-sleep-watch".source = countdownSleepWatch;
}
