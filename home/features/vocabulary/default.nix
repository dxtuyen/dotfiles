{
  config,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../../../shared/theme.nix;
  configureGoldenDict = pkgs.writeShellApplication {
    name = "goldendict-anki-config";
    runtimeInputs = [
      pkgs.python3
      pkgs.procps
    ];
    text = ''
      exec python3 ${./scripts/configure-goldendict.py} \
        --config ${lib.escapeShellArg "${config.xdg.configHome}/goldendict/config"} \
        --dictionary ${lib.escapeShellArg "${config.home.homeDirectory}/Dictionary/Longman"} \
        "$@"
    '';
  };
  longmanSetup = pkgs.writeShellApplication {
    name = "anki-longman-setup";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      ${configureGoldenDict}/bin/goldendict-anki-config
      exec python3 ${./.}/scripts/apply-longman.py "$@"
    '';
  };
in
{
  home.packages = [
    pkgs.goldendict-ng
    pkgs.anki
    configureGoldenDict
    longmanSetup
  ];

  # Preserve Longman's layout; substitute colors from the shared palette.
  xdg.configFile."goldendict/article-style.css" = {
    source = pkgs.replaceVars ./assets/goldendict/longman.css {
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

  # Seed a fresh install and update only managed preferences in existing XML.
  # A running GoldenDict would overwrite edits when it exits, so defer those.
  home.activation.goldendictPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${configureGoldenDict}/bin/goldendict-anki-config --skip-running
  '';
}
