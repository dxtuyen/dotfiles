{ pkgs, ... }:

{
  home.file.".local/bin/media-notify" = {
    executable = true;
    text =
      builtins.replaceStrings
        [ "@flock@" "@timeout@" ]
        [
          "${pkgs.util-linux}/bin/flock"
          "${pkgs.coreutils}/bin/timeout"
        ]
        (builtins.readFile ./media-notify.sh);
  };
}
