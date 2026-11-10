{ pkgs, ... }:

let
  sessionPolicy = import ../../../shared/session-policy.nix;
  utilities = pkgs.writeShellApplication {
    name = "utilities";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.tofi
      pkgs.systemd
      pkgs.power-profiles-daemon
      pkgs.sway
      pkgs.libnotify
      pkgs.foot
      pkgs.bluetui
      pkgs.wiremix
    ];
    extraShellCheckFlags = [ "--external-sources" ];
    text =
      builtins.replaceStrings
        [ "# shellcheck source=../../tofi/scripts/menu.sh" "@sleepAction@" ]
        [ "# shellcheck source=${../tofi/scripts/menu.sh}" sessionPolicy.sleepAction ]
        (builtins.readFile ./scripts/utilities.sh);
  };
  powerProfileMenu = pkgs.writeShellApplication {
    name = "power-profile-menu";
    text = "exec ${utilities}/bin/utilities --power-profile";
  };
in
{
  home.packages = [
    pkgs.wiremix
    pkgs.bluetui
  ];
  home.file = {
    ".local/bin/utilities".source = "${utilities}/bin/utilities";
    ".local/bin/power-profile-menu".source = "${powerProfileMenu}/bin/power-profile-menu";
  };
}
