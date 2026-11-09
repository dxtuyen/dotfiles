{ pkgs, ... }:

let
  quickLang = pkgs.writeShellApplication {
    name = "quick-lang";
    # This workflow handles API/network failures and fallback explicitly.
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.curl
      pkgs.jq
      pkgs.wl-clipboard
      pkgs.libnotify
      pkgs.mako
    ];
    text = builtins.readFile ./scripts/quick-lang.sh;
  };
in
{
  home.file.".local/bin/quick-lang".source = "${quickLang}/bin/quick-lang";
}
