{
  config,
  lib,
  pkgs,
  ...
}:

let
  configureBtop = pkgs.writeShellApplication {
    name = "configure-btop";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = builtins.readFile ./scripts/configure-btop.sh;
  };
in
{
  programs.btop.enable = true;
  # Preserve writable layout/sort preferences; manage appearance at activation.
  home.activation.btopMaterial = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${configureBtop}/bin/configure-btop \
      ${lib.escapeShellArg "${config.xdg.configHome}/btop/btop.conf"} \
      ${lib.escapeShellArg "${pkgs.btop}/share/btop/themes/gruvbox_material_dark.theme"}
  '';
}
