let
  width = 70;
  height = 85;
in
{
  # Initial geometry only; Sway owns later resizing and floating splits.
  commands = "floating enable, move scratchpad, scratchpad show, resize set width ${toString width} ppt height ${toString height} ppt, move position center";
}
