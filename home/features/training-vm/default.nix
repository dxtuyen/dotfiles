{ pkgs, ... }:

let
  vmNixos = pkgs.writeShellApplication {
    name = "vm-nixos";
    runtimeInputs = [
      pkgs.findutils
      pkgs.coreutils
      pkgs.qemu_kvm
    ];
    text = builtins.replaceStrings [ "@ovmf@" ] [ "${pkgs.OVMF.firmware}" ] (
      builtins.readFile ./scripts/vm-nixos.sh
    );
  };
in
{
  home.packages = [
    pkgs.qemu_kvm
    pkgs.qemu-utils
    pkgs.OVMF
  ];
  home.file.".local/bin/vm-nixos".source = "${vmNixos}/bin/vm-nixos";
}
