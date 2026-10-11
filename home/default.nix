{ userName, ... }:

# Main Home Manager entry point for this user.

{
  home = {
    username = userName;
    homeDirectory = "/home/${userName}";
    stateVersion = "26.05";
  };

  imports = [
    ./xdg.nix
    ./packages.nix
    ./shell
    ./programs
    ./desktop
    ./features
    ./scripts
  ];

  programs.home-manager.enable = true;
}
