{ ... }:

# Mod+u opens daily tools; Mod+p and the Waybar power button open power actions.
{
  home.file.".local/bin/utilities" = {
    executable = true;
    text = builtins.readFile ./daily-menu.sh;
  };
}
