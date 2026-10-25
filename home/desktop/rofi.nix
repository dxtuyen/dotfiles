{ ... }:

let
  theme = import ../theme.nix;
in

{
  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
      modi: "drun,run,window";
      show-icons: true;
      drun-display-format: "{name}";
      font: "JetBrains Mono 12";
      location: 0;
      disable-history: false;
      hover-select: false;
      me-select-entry: "";
      me-accept-entry: "MousePrimary";
      kb-cancel: "Escape,Control+g,Control+bracketleft,MouseSecondary";
    }

    @theme "gruvbox-dark"
  '';

  xdg.configFile."rofi/gruvbox-dark.rasi".text = ''
    * {
      bg:                 ${theme.bg0};
      surface:            ${theme.bg1};
      surface-hover:      ${theme.bg2};
      fg:                 ${theme.fg1};
      fg-strong:          ${theme.fg0};
      muted:              ${theme.fg3};
      accent:             ${theme.fg3};
      aqua:               ${theme.aqua};
      accent-bright:      ${theme.fg3};
      red:                ${theme.red};
      background-color:   transparent;
      text-color:         @fg;
      margin:             0;
      padding:            0;
      spacing:            0;
    }

    window {
      width:              42%;
      transparency:       "real";
      border:             1px;
      border-color:       @accent;
      border-radius:      6px;
      background-color:   @bg;
    }

    mainbox {
      padding:            16px;
      spacing:            10px;
      background-color:   @bg;
      border-radius:      7px;
    }

    inputbar {
      padding:            11px 14px;
      spacing:            9px;
      border:             1px;
      border-color:       @surface-hover;
      border-radius:      7px;
      background-color:   @surface;
      children:           [ "prompt", "entry" ];
    }

    prompt {
      text-color:         @accent-bright;
      font:               "JetBrains Mono Bold 12";
    }

    entry {
      placeholder:        "Search applications…";
      placeholder-color:  @muted;
      text-color:         @fg;
    }

    message {
      padding:            0 4px;
      background-color:   transparent;
    }

    textbox {
      text-color:         @muted;
      background-color:   transparent;
    }

    listview {
      columns:            1;
      lines:              8;
      fixed-height:       true;
      cycle:              true;
      scrollbar:          true;
      spacing:            4px;
      background-color:   transparent;
    }

    element {
      padding:            8px 10px;
      border-radius:      6px;
      background-color:   transparent;
      text-color:         @fg;
    }

    element normal.normal {
      text-color:         @fg;
    }

    element normal.active {
      text-color:         @accent-bright;
    }

    element normal.urgent {
      text-color:         @red;
    }

    element selected.normal {
      background-color:   @surface-hover;
      text-color:         @fg-strong;
    }

    element selected.active {
      background-color:   @surface-hover;
      text-color:         @fg-strong;
    }

    element selected.urgent {
      background-color:   @surface-hover;
      text-color:         @red;
    }

    element-icon {
      size:               24px;
      margin:             0 10px 0 0;
      background-color:   transparent;
    }

    element-text {
      vertical-align:     0.5;
      background-color:   transparent;
    }

    scrollbar {
      handle-width:       4px;
      border:             0;
      border-color:       @bg;
      background-color:   @bg;
      handle-color:       @accent;
    }
  '';
}
