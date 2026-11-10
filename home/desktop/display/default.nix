{ pkgs, ... }:

let
  wlsunsetApply = pkgs.writeShellApplication {
    name = "wlsunset-apply";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/wlsunset-apply.sh;
  };
  wlsunsetRun = pkgs.writeShellApplication {
    name = "wlsunset-run";
    runtimeInputs = [ pkgs.wlsunset ];
    text = builtins.readFile ./scripts/wlsunset-run.sh;
  };
  wlsunsetMenu = pkgs.writeShellApplication {
    name = "wlsunset-menu";
    runtimeInputs = [
      pkgs.systemd
      pkgs.fuzzel
      pkgs.libnotify
    ];
    extraShellCheckFlags = [ "--external-sources" ];
    text =
      builtins.replaceStrings
        [ "# shellcheck source=../../fuzzel/scripts/menu.sh" ]
        [ "# shellcheck source=${../fuzzel/scripts/menu.sh}" ]
        (builtins.readFile ./scripts/wlsunset-menu.sh);
  };
in
{
  home.packages = [ pkgs.wlsunset ];
  systemd.user.services."wlsunset@" = {
    Unit = {
      Description = "Display temperature (%i)";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      # Explicit menu selections may restart the same mode several times.
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "exec";
      ExecStart = "${wlsunsetRun}/bin/wlsunset-run %i";
    };
  };

  home.file = {
    ".local/bin/wlsunset-apply".source = "${wlsunsetApply}/bin/wlsunset-apply";
    ".local/bin/wlsunset-menu".source = "${wlsunsetMenu}/bin/wlsunset-menu";
  };
}
