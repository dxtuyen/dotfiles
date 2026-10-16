{ ... }:

# Vietnamese input: Fcitx5 + Lotus.
{
  xdg.configFile = {
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
