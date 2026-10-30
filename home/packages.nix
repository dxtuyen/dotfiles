{ pkgs, ... }:

let
  swayview = pkgs.callPackage ../pkgs/swayview.nix { };
in

# User packages from the nixos-unstable revision pinned in flake.lock.
{

  home.packages = with pkgs; [
    rofi
    swayview # overview and switcher for Sway workspaces (Mod+Tab)
    wlsunset
    grim
    slurp
    wl-clipboard
    swaylock
    swayidle
    libnotify
    wiremix # PipeWire mixer (terminal UI).
    # Btop is installed by its Home Manager module.
    brightnessctl
    translate-shell
    goldendict-ng
    wifitui # Wi-Fi management TUI.
    anki
    bluetui
    google-chrome
    brave
    # E-book reader.
    foliate
    imv # Image viewer.
    mpv # Media player.
    ripgrep # Fast text search.
    fd # Fast file search.
    dust # Disk usage charts.
    ncdu # Interactive disk usage browser.
    sioyek
    obsidian
    vscode
    jq
    fastfetch
    libreoffice
    mysql-workbench
    # Development tools.
    python3
    python3Packages.virtualenv
    gcc
    gnumake
    cmake
    gdb
    jdk
    distrobox
    gh # GitHub CLI.
    # Virtual machine tools.
    qemu_kvm
    qemu-utils
    OVMF
  ];
}
