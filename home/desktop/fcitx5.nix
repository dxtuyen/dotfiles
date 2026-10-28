{ ... }:

let
  theme = import ../theme.nix;
in
# Vietnamese input: Fcitx5 + Lotus.
{
  xdg.configFile = {
    "fcitx5/conf/classicui.conf".text = ''
      Theme=gruvbox-material
      DarkTheme=gruvbox-material
      UseDarkTheme=True
      UseAccentColor=False
    '';
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

  xdg.dataFile."fcitx5/themes/gruvbox-material/theme.conf".text = ''
    [Metadata]
    Name=Gruvbox Material
    Version=1
    Description=Dark medium palette shared with the desktop
    ScaleWithDPI=True

    [InputPanel]
    NormalColor=${theme.fg1}
    HighlightColor=${theme.fg0}

    [InputPanel/Background]
    Color=${theme.bg0}
    BorderColor=${theme.bg4}
    BorderWidth=1

    [InputPanel/Highlight]
    Color=${theme.selection}

    [InputPanel/TextMargin]
    Left=8
    Right=8
    Top=6
    Bottom=6

    [Menu]
    NormalColor=${theme.fg1}
    HighlightColor=${theme.fg0}

    [Menu/Background]
    Color=${theme.bg0}
    BorderColor=${theme.bg4}
    BorderWidth=1

    [Menu/Highlight]
    Color=${theme.selection}

    [Menu/Separator]
    Color=${theme.bg3}
  '';
}
