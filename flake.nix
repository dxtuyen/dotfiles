{
  description = "Doxuan Tuyen's reproducible NixOS laptop";

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
      pkgs = nixpkgs.legacyPackages.${system};
      # Preview aliases use the same resolution as the laptop's Home Manager config.
      wallpapers = import ./home/features/wallpaper/images.nix {
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

      checks.${system}.workflows =
        pkgs.runCommand "workflow-regressions"
          {
            nativeBuildInputs = with pkgs; [
              python3
              bash
              coreutils
              jq
              util-linux
            ];
          }
          ''
            cd ${self}
            python3 -m unittest discover -s tests -v
            touch "$out"
          '';

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
          inherit inputs;
          userName = "doxuantuyen";
        };
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/laptop
        ];
      };
    };
}
