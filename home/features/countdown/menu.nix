{ pkgs, ... }:

let
  countdownMenu = pkgs.writeTextFile {
    name = "countdown-menu";
    executable = true;
    text = builtins.readFile ./countdown-menu.sh;
  };
in
{
  home.file.".local/bin/countdown".source = countdownMenu;
}
