{ pkgs, userName, ... }:

let
  # Keep the TTY's system palette; customize only these tuigreet components.
  greeterTheme = builtins.concatStringsSep ";" [
    "border=bright-black"
    "time=bright-blue"
    "input=bright-cyan"
  ];
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
    plugins = with pkgs; [ tumbler ];
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
      command = "${pkgs.tuigreet}/bin/tuigreet --time --user ${userName} --cmd sway --theme '${greeterTheme}'";
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

  environment.sessionVariables = {
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
}
