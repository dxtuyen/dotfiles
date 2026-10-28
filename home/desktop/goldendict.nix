{
  config,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../theme.nix;
in
{
  # Preserve Longman's layout; substitute colors from the shared palette.
  xdg.configFile."goldendict/article-style.css" = {
    source = pkgs.replaceVars ../assets/goldendict/longman.css {
      inherit (theme)
        bg0
        bg1
        bg2
        bg3
        bg4
        fg0
        fg1
        red
        blue
        aqua
        purple
        selectionBlue
        ;
    };
    force = true;
  };

  # GoldenDict keeps these preferences in its app-managed config. Update only
  # the appearance fields so dictionary and user settings remain untouched.
  home.activation.goldendictDarkMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    configFile="${config.xdg.configHome}/goldendict/config"
    if [ -f "$configFile" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e 's#<displayStyle>[^<]*</displayStyle>#<displayStyle>modern</displayStyle>#' \
        -e 's#<darkMode>[^<]*</darkMode>#<darkMode>1</darkMode>#' \
        -e 's#<darkReaderMode>[^<]*</darkReaderMode>#<darkReaderMode>0</darkReaderMode>#' \
        "$configFile"
    fi
  '';
}
