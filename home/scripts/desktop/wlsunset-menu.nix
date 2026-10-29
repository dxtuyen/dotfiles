{ ... }:

{
  home.file.".local/bin/wlsunset-menu" = {
    executable = true;
    text = builtins.readFile ./wlsunset-menu.sh;
  };
}
