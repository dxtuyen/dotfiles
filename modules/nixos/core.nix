{
  lib,
  pkgs,
  userName,
  ...
}:

let
  theme = import ../../home/theme.nix;
in
{
  # Run garbage collection weekly and keep the last seven days.
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot = {
    enable = true;
    # Keep at most 10 boot entries.
    configurationLimit = 10;
  };
  # Keep the recovery menu available briefly without adding a long pause.
  boot.loader.timeout = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  # The systemd-based initrd is the NixOS default. Plymouth (with
  # plymouth.use-simpledrm keeping the framebuffer early) covers the
  # khoảng đen giữa menu boot và logo, không còn hẫng màn hình.
  boot.consoleLogLevel = 3;
  boot.plymouth = {
    enable = true;
    theme = "nixos-bgrt";
    themePackages = [ pkgs.nixos-bgrt-plymouth ];
  };
  boot.kernelParams = [
    "quiet"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "plymouth.use-simpledrm"
    # Avoid fbcon taking over the console after tuigreet has already drawn.
    "fbcon=nodefer"
  ];

  networking = {
    networkmanager = {
      enable = true;
      # Use systemd-resolved for DNS caching and fallback.
      dns = "systemd-resolved";
    };
    firewall.enable = true;
  };
  services.resolved.enable = true;
  # Disable nscd to avoid stale NSS cache entries.
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
  programs.nh = {
    enable = true;
    # nh uses this flake by default.
    flake = "/home/${userName}/nix-config";
  };

  time.timeZone = "Asia/Ho_Chi_Minh";
  services.timesyncd.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  console.colors = map (color: builtins.substring 1 6 color) theme.ansi;

  users.users.${userName} = {
    isNormalUser = true;
    description = "Doxuan Tuyen";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # Keep SSH keys unlocked for the login session (see docs/personal/cai-laptop.md).
  programs.ssh.startAgent = true;

  # Basic tools available from the system profile.
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    unzip
    zip
    htop
    btop
    file # Inspect file types.
  ];
}
