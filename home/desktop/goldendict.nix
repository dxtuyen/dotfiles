{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Keep Longman's layout while applying a readable Gruvbox Dark color layer.
  xdg.configFile."goldendict/article-style.css" = {
    source = ../assets/goldendict/longman.css;
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
