{
  config,
  inputs,
  lib,
  pkgs,
  userName,
  ...
}:

let
  fcitxPackage = config.i18n.inputMethod.package;
  fcitxAddons = config.i18n.inputMethod.fcitx5.addons;
  fcitxAddonDirs = lib.makeSearchPath "lib/fcitx5" fcitxAddons;
  fcitxDataDirs = lib.makeSearchPath "share/fcitx5" fcitxAddons;
  # The upstream flake's v5.0.3 tag still declares v5.0.2 in its Nix
  # package expression, so pin both the real source tag and derivation version.
  lotusPackage =
    inputs.lotus.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-lotus.overrideAttrs
      (_: {
        version = "5.0.3";
        src = pkgs.fetchFromGitHub {
          owner = "LotusInputMethod";
          repo = "fcitx5-lotus";
          tag = "v5.0.3";
          hash = "sha256-XTyXzO0rF0zkW9li0sFBSAf+qakU9uFxl1CrQVlbMms=";
        };
      });
in
{

  programs.sway.enable = true;
  programs.dconf.enable = true;

  # Enable remote and virtual filesystems for GIO and Thunar.
  services.gvfs.enable = true;

  # Manage Thunar at the system level so its plugins stay available.
  # Use Tumbler for thumbnails; avoid plugins that pull in extra GNOME services.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      tumbler
    ];
  };

  hardware.graphics.enable = true;

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      # Keep the known username prefilled while still requiring the password.
      command = "${pkgs.tuigreet}/bin/tuigreet --time --user ${userName} --cmd sway";
      user = "greeter";
    };
  };

  systemd.tmpfiles.rules = [
    # WebKitGTK expects dictionaries under /usr/share/hyphen; provide the en_US link.
    "L+/usr/share/hyphen - - - - ${pkgs.hyphenDicts.en_US}/share/hyphen"
  ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
    ];
  };

  # Lotus uses its uinput server for direct key replacement without preedit.
  # The upstream module manages its package, udev rules, and systemd service.
  boot.kernelModules = [ "uinput" ];
  services.fcitx5-lotus = {
    enable = true;
    users = [ userName ];
    package = lotusPackage;
  };

  environment.sessionVariables = {
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    # Run Electron and Chromium apps natively on Wayland.
    NIXOS_OZONE_WL = "1";
    # Route GTK file dialogs through xdg-desktop-portal for consistent Sway rules.
    GTK_USE_PORTAL = "1";
  };

  fonts = {
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      font-awesome
      noto-fonts
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
      monospace = [ "JetBrains Mono" ];
    };
  };

  # WebKitGTK dictionaries are already linked in the block above.

  # Optional wallpaper rotation timer; enable these units to use it.
  # systemd.user.services.wallpaper-rotate = {
  #   description = "Rotate wallpaper";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "%h/.local/bin/wallpaper-set";
  #   };
  # };
  # systemd.user.timers.wallpaper-rotate = {
  #   description = "Rotate wallpaper every 30 minutes";
  #   timerConfig = { OnActiveSec = "30min"; AccuracySec = "1min"; };
  #   # No wantedBy: start the timer manually.
  # };

  systemd.user.services.fcitx5-daemon = {
    description = "Fcitx5 input method daemon";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${fcitxPackage}/bin/fcitx5";
      Environment = [
        # Fcitx ignores addon metadata exposed as buildEnv symlinks.
        "FCITX_ADDON_DIRS=${fcitxAddonDirs}:${fcitxPackage}/lib/fcitx5"
        "FCITX_DATA_DIRS=${fcitxDataDirs}:${fcitxPackage}/share/fcitx5"
      ];
      Restart = "on-failure";
      RestartSec = "2";
    };
  };
}
