{ pkgs, ... }:

# User packages from the nixos-unstable revision pinned in flake.lock.
{

  services.flatpak = {
    enable = true;
    packages = [
      "com.brave.Browser"
      "com.ticktick.TickTick"
      "com.super_productivity.SuperProductivity"
    ];
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    update.auto = {
      enable = true;
      onCalendar = "daily";
    };
  };

  home.packages = with pkgs; [
    translate-shell
    google-chrome
    (pkgs.writeShellScriptBin "brave" ''
      exec ${pkgs.flatpak}/bin/flatpak run --user com.brave.Browser "$@"
    '')
    # E-book reader.
    foliate
    imv # Image viewer.
    mpv # Media player.
    ripgrep # Fast text search.
    fd # Fast file search.
    dust # Disk usage charts.
    ncdu # Interactive disk usage browser.
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
  ];
}
