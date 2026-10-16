{ lib, pkgs, ... }:

let
  batteryThreshold = pkgs.writeShellApplication {
    name = "set-battery-threshold";
    text = ''
      start_threshold=85
      end_threshold=90
      configured=0
      for battery in /sys/class/power_supply/BAT*; do
        [ -d "$battery" ] || continue
        if [ -e "$battery/charge_control_start_threshold" ]; then
          start_file="$battery/charge_control_start_threshold"
        elif [ -e "$battery/charge_start_threshold" ]; then
          start_file="$battery/charge_start_threshold"
        else continue; fi
        if [ -e "$battery/charge_control_end_threshold" ]; then
          end_file="$battery/charge_control_end_threshold"
        elif [ -e "$battery/charge_stop_threshold" ]; then
          end_file="$battery/charge_stop_threshold"
        else continue; fi
        printf '%s\n' "$start_threshold" > "$start_file"
        printf '%s\n' "$end_threshold" > "$end_file"
        configured=1
      done
      [ "$configured" -eq 1 ] || echo "Battery does not expose charge thresholds."
    '';
  };
in
{
  # Load Intel KMS early so the console does not resize under tuigreet.
  boot.initrd.kernelModules = [ "i915" ];

  # Compressed swap in RAM (zstd): faster than SSD swap, less disk wear.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Hibernate: auto-detect the resume device from the filesystem label.
  # The swap partition is formatted with the label 'swap' (mkswap -L swap).
  # Requirement: swap >= RAM. On a new machine, just label the swap partition
  # and it matches automatically — no manual UUID editing. deep sleep saves
  # more battery than s2idle.
  boot.resumeDevice = lib.mkDefault "/dev/disk/by-label/swap";
  boot.kernelParams = [
    "mem_sleep_default=deep"
  ];

  services.fwupd.enable = true;
  # Keep firmware updates but stop the daemon from blocking greetd at login.
  systemd.services.fwupd.before = lib.mkForce [ "shutdown.target" ];

  # Close lid -> suspend; docked -> ignore. The screen always locks on wake
  # thanks to swayidle's before-sleep.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "overload(control, esc)";
        };
        # Press both shift keys together -> toggle the real CapsLock.
        # Holding a shift key activates keyd's implicit [shift] layer, so
        # pressing the other shift in that state sends capslock instead of
        # a second shift — the standard community remap, which restores a
        # CapsLock toggle now that the caps key itself is Ctrl/Esc.
        shift = {
          leftshift = "capslock";
          rightshift = "capslock";
        };
      };
    };
  };

  systemd.services.battery-threshold = {
    description = "Set battery charge threshold to 85-90 percent";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${batteryThreshold}/bin/set-battery-threshold";
    };
  };
}
