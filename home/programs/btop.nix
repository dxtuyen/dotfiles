{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.btop.enable = true;

  # Btop saves layout/sort preferences into its config. Preserve those and
  # update only appearance instead of making the whole file immutable.
  home.activation.btopMaterial = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    configFile="${config.xdg.configHome}/btop/btop.conf"
    run mkdir -p "$(dirname "$configFile")"
    if [ -f "$configFile" ]; then
      if [ ! -f "$configFile.before-gruvbox-material" ]; then
        run cp -p "$configFile" "$configFile.before-gruvbox-material"
      fi
      run ${pkgs.gnused}/bin/sed -i '/^color_theme = /d; /^theme_background = /d; /^truecolor = /d' "$configFile"
    fi
    if [[ ! -v DRY_RUN ]]; then
      cat >> "$configFile" <<'EOF'
    color_theme = "${pkgs.btop}/share/btop/themes/gruvbox_material_dark.theme"
    theme_background = True
    truecolor = True
    EOF
    fi
  '';
}
