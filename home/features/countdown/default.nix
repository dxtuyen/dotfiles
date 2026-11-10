{ pkgs, ... }:

let
  countdownEngine = pkgs.writeShellApplication {
    name = "countdown-engine";
    # State transitions explicitly handle errors; preserve their exit behavior.
    bashOptions = [ ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.jq
      pkgs.systemd
      pkgs.procps
      pkgs.inotify-tools
      pkgs.libnotify
      pkgs.pulseaudio
    ];
    text =
      builtins.replaceStrings
        [ "@flock@" "@jq@" "@alarmSound@" ]
        [
          "${pkgs.util-linux}/bin/flock"
          "${pkgs.jq}/bin/jq"
          "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        ]
        (builtins.readFile ./scripts/countdown-engine.sh);
  };
  countdownMenu = pkgs.writeShellApplication {
    name = "countdown";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fuzzel
      pkgs.libnotify
    ];
    extraShellCheckFlags = [ "--external-sources" ];
    text =
      builtins.replaceStrings
        [ "# shellcheck source=../../../desktop/fuzzel/scripts/menu.sh" ]
        [ "# shellcheck source=${../../desktop/fuzzel/scripts/menu.sh}" ]
        (builtins.readFile ./scripts/countdown-menu.sh);
  };
in
{
  imports = [ ./services.nix ];
  home.file = {
    ".local/bin/countdown-engine".source = "${countdownEngine}/bin/countdown-engine";
    ".local/bin/countdown".source = "${countdownMenu}/bin/countdown";
  };
}
