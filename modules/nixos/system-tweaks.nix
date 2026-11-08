{ ... }:

{
  # Upgrade NixOS manually after reviewing and validating flake.lock changes.
  system.autoUpgrade.enable = false;

  # Kill memory-heavy processes before the desktop runs out of memory.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    enableNotifications = true;
  };
  # Use earlyoom as the sole out-of-memory manager.
  systemd.oomd.enable = false;

  # Run weekly TRIM on SSDs and NVMe drives.
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Run prebuilt binaries such as VS Code Server and JetBrains tools.
  programs.nix-ld.enable = true;
}
