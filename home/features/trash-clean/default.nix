{ pkgs, ... }:

let
  trashClean = pkgs.writeShellApplication {
    name = "trash-clean";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = builtins.readFile ./scripts/trash-clean.sh;
  };
in
{
  imports = [ ./services.nix ];
  home.file.".local/bin/trash-clean".source = "${trashClean}/bin/trash-clean";
}
