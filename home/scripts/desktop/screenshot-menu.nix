{ ... }:

{
  home.file.".local/bin/screenshot-menu" = {
    executable = true;
    text = builtins.readFile ./screenshot-menu.sh;
  };
}
