{ ... }:

# Vietnamese input: Fcitx5 + Lotus.
{
  xdg.configFile = {
    # Disable Fcitx5's single-Shift temporary input-method switch.
    "fcitx5/config" = {
      text = ''
        [Hotkey/AltTriggerKeys]
      '';
      force = true;
    };
    "fcitx5/profile".text = ''
      [Groups/0]
      Name=Default
      Default Layout=us
      DefaultIM=lotus
      [Groups/0/Items/0]
      Name=keyboard-us
      Layout=
      [Groups/0/Items/1]
      Name=lotus
      Layout=
      [GroupOrder]
      0=Default
    '';
  };
}
