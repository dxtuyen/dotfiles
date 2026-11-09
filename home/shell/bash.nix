{ ... }:

{
  programs.bash = {
    enable = true;
    shellAliases.nswitch = ''cd "$HOME/dotfiles" && sudo nixos-rebuild switch --flake ".#$(hostname -s)"'';
    initExtra = builtins.readFile ./scripts/interactive.sh;
  };
}
