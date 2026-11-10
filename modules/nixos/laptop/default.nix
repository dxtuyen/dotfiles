{ lib, pkgs, ... }:

let
  sessionPolicy = import ../../../shared/session-policy.nix;
  batteryThreshold = pkgs.writeShellApplication {
    name = "set-battery-threshold";
    text = builtins.readFile ./scripts/set-battery-threshold.sh;
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

  systemd.sleep.settings.Sleep.HibernateDelaySec = sessionPolicy.hibernateDelay;

  services.fwupd.enable = true;
  # Keep firmware updates but stop the daemon from blocking greetd at login.
  systemd.services.fwupd.before = lib.mkForce [ "shutdown.target" ];

  # Close lid -> sleep, even on AC; docked -> ignore. Session locking and
  # application sleep observers independently handle logind's sleep event.
  services.logind.settings.Login = {
    HandleLidSwitch = sessionPolicy.sleepAction;
    HandleLidSwitchExternalPower = sessionPolicy.sleepAction;
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
