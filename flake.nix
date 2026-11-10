{
  description = "Personal dotfiles for NixOS and Home Manager";

  inputs = {
    # Rolling release (nixos-unstable), checked through CI evaluation and
    # protected by NixOS generations for rollback — following matklad's
    # "Use NixOS-unstable" trick.
    # "Unstable" is a misnomer: it is actually a fairly stable continuous release.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager develops against nixpkgs-unstable, so use master directly
    # to avoid module/package skew.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/latest";

    # Use only the generator source, with this system's pinned Nixpkgs.
    nix-wallpaper = {
      url = "github:lunik1/nix-wallpaper";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      userName = "doxuantuyen";
      pkgs = nixpkgs.legacyPackages.${system};
      # Preview aliases use the same resolution as the laptop's Home Manager config.
      wallpapers = import ./home/desktop/wallpaper/images.nix {
        inherit pkgs inputs;
        wallpaperResolution =
          self.nixosConfigurations.laptop.config.home-manager.extraSpecialArgs.wallpaperResolution or { };
      };
    in
    {
      packages.${system} = {
        wallpaper-desktop = wallpapers.desktop;
        wallpaper-lockscreen = wallpapers.lockscreen;
      };

      checks.${system} = {
        workflows =
          pkgs.runCommand "workflow-regressions"
            {
              nativeBuildInputs = with pkgs; [
                python3
                bash
                coreutils
                jq
                util-linux
                sway-unwrapped
                foot
              ];
              FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
            }
            ''
              cd ${self}
              python3 -m unittest discover -s tests -v
              touch "$out"
            '';

        # Build packaged commands and lint sourced shell helpers.
        scripts =
          let
            homeConfig = self.nixosConfigurations.laptop.config.home-manager.users.${userName};
            sessionUnitNames = [
              "sway-session.target"
              "session-locked.target"
              "swaylock.service"
              "locked-display.service"
              "session-lock.service"
              "swayidle.service"
              "idle-suspend.service"
              "idle-suspend.timer"
              "countdown-engine.service"
              "countdown-idle-inhibit.service"
              "countdown-lock-pause.service"
              "countdown-sleep.service"
            ];
            sessionUnitFiles = nixpkgs.lib.filterAttrs (
              name: _:
              nixpkgs.lib.hasPrefix "systemd/user/" name
              && builtins.elem (builtins.baseNameOf name) sessionUnitNames
            ) homeConfig.xdg.configFile;
            sessionUnits = pkgs.linkFarm "session-unit-checks" (
              nixpkgs.lib.mapAttrsToList (name: file: {
                name = nixpkgs.lib.removePrefix "systemd/user/" name;
                path = file.source;
              }) sessionUnitFiles
            );
            commands = [
              "obsidian-toggle"
              "ticktick-toggle"
              "sway-popup"
              "scratchpad-terminal"
              "screenshot"
              "screenshot-menu"
              "toggle-touchpad"
              "wlsunset-apply"
              "wlsunset-menu"
              "refresh-session"
              "idle-suspend"
              "lock-screen"
              "session-resume"
              "media-notify"
              "utilities"
              "power-profile-menu"
              "dict-toggle"
              "quick-lang"
              "vm-nixos"
              "trash-clean"
              "countdown-engine"
              "countdown"
              "sioyek-open"
              "sioyek"
            ];
          in
          pkgs.runCommand "script-checks"
            {
              nativeBuildInputs = [
                pkgs.shellcheck
                pkgs.python3
                pkgs.systemd
              ];
              scripts = map (name: homeConfig.home.file.".local/bin/${name}".source) commands;
              # Keep activation-only and system command helpers in the build graph.
              btopActivation = homeConfig.home.activation.btopMaterial.data;
              vocabularyPackages = builtins.filter (
                package:
                builtins.elem (nixpkgs.lib.getName package) [
                  "goldendict-anki-config"
                  "anki-longman-setup"
                ]
              ) homeConfig.home.packages;
              batteryCommand =
                self.nixosConfigurations.laptop.config.systemd.services.battery-threshold.serviceConfig.ExecStart;
              runner = builtins.head (
                nixpkgs.lib.splitString " " (
                  toString homeConfig.systemd.user.services."wlsunset@".Service.ExecStart
                )
              );
            }
            ''
              for script in $scripts; do
                test -x "$script"
              done
              test -x "$runner"
              shellcheck -s bash ${./home/shell/scripts/interactive.sh} ${./home/desktop/rofi/scripts/rofi-menu.sh}
              python3 ${./tests/check_session_units.py} ${sessionUnits} \
                ${pkgs.systemd}/example/systemd/user \
                ${homeConfig.home.file.".local/bin/countdown-engine".source}
              touch "$out"
            '';
      };

      formatter.${system} = pkgs.writeShellApplication {
        name = "nixfmt";
        text = ''
          ${pkgs.findutils}/bin/find . -path ./.git -prune -o -type f -name '*.nix' -print0 \
            | ${pkgs.findutils}/bin/xargs --no-run-if-empty -0 ${pkgs.nixfmt}/bin/nixfmt "$@"
        '';
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs userName;
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/laptop
        ];
      };
    };
}
