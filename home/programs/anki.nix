{ pkgs, ... }:

let
  theme = import ../theme.nix;
in
{
  # Card CSS lives in Anki's collection, rather than in a config file. Generate
  # the stylesheet here; use Yanki/AnkiConnect to apply it to managed note types.
  xdg.configFile."anki/yanki-dark.css".source = pkgs.replaceVars ../assets/anki/yanki-dark.css.in {
    inherit (theme)
      bg0
      bg1
      bg3
      fg1
      blue
      ;
  };
}
