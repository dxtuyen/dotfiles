{
  description = "Doxuan Tuyen's reproducible NixOS laptop";

  inputs = {
    # Rolling release (nixos-unstable), gated by a test suite + trivial rollback
    # generations — following matklad's "Use NixOS-unstable" trick.
    # "Unstable" is a misnomer: it is actually a fairly stable continuous release.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager develops against nixpkgs-unstable, so use master directly
    # to avoid module/package skew.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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
    in
    {
      formatter.${system} = pkgs.writeShellApplication {
        name = "nixfmt";
        text = ''
          ${pkgs.findutils}/bin/find . -type f -name '*.nix' -print0 \
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
