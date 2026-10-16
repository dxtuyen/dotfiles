{ pkgs, ... }:

let
  swayview = pkgs.callPackage ../pkgs/swayview.nix { };
in

# User packages from the nixos-unstable revision pinned in flake.lock.
{

  home.packages = with pkgs; [
    rofi
    swayr # switch windows by focus history (Alt+Tab-style MRU)
    swayview # overview and switcher for Sway workspaces
    wlsunset
    grim
    slurp
    wl-clipboard
    swaylock
    swayidle
    awww # Wallpaper daemon with animated transitions.
    libnotify
    wiremix # PipeWire mixer (terminal UI).
    brightnessctl
    translate-shell
    goldendict-ng
    wifitui # Wi-Fi management TUI.

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
    # Zotero is temporarily disabled because the pinned package fails to build:
    #   AboutTranslations: ... not found in modules/ActorManagerParent.sys.mjs -- aborting
    # Re-enable after updating nixpkgs to a working version.
    #qzotero # Reference manager.
    jq
    fastfetch
    libreoffice
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
