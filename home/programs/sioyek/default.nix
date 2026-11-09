{ pkgs, ... }:

let
  sioyekOpen = pkgs.writeShellApplication {
    name = "sioyek-open";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.jq
      pkgs.sway
      pkgs.sioyek
    ];
    text = builtins.readFile ./scripts/sioyek-open.sh;
  };
  sioyek = pkgs.writeShellApplication {
    name = "sioyek";
    text = ''exec ${sioyekOpen}/bin/sioyek-open "$@"'';
  };
in
{
  imports = [ ./config.nix ];
  home.packages = [ pkgs.sioyek ];
  home.file = {
    ".local/bin/sioyek-open".source = "${sioyekOpen}/bin/sioyek-open";
    ".local/bin/sioyek".source = "${sioyek}/bin/sioyek";
  };
}
