{
  inputs,
  userName,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/database.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/input-method.nix
    ../../modules/nixos/laptop
    ../../modules/nixos/system-tweaks.nix
    ../../modules/nixos/virtualisation.nix
  ];

  networking.hostName = "laptop";

  # Home-manager is configured centrally here.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];
    backupFileExtension = "backup"; # overwrite old file as *.backup instead of failing the build
    extraSpecialArgs = { inherit inputs userName; };
    users.${userName} = import ../../home;
  };

  system.stateVersion = "26.05";
}
