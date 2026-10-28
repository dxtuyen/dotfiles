{ pkgs, ... }:

let
  swayview = pkgs.callPackage ../pkgs/swayview.nix { };
in

# User packages from the nixos-unstable revision pinned in flake.lock.
{

  home.packages = with pkgs; [
    rofi
    swayview # overview and switcher for Sway workspaces
    wlsunset
    grim
    slurp
    wl-clipboard
    swaylock
    swayidle
    libnotify
    wiremix # PipeWire mixer (terminal UI).
    btop # Terminal resource monitor; usable inside the Mod+grave popup.
    brightnessctl
    translate-shell
    goldendict-ng
    wifitui # Wi-Fi management TUI.
    anki
    bluetui
    google-chrome
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
    jq
    fastfetch
    libreoffice
    mysql-workbench
    # Development tools.
    vscode
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
