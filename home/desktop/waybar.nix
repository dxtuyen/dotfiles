{ config, ... }:

let
  theme = import ../theme.nix;
  # Use Font Awesome for consistent icon sizing and alignment.
  faSpan = s: "<span font_family='Font Awesome 7 Free'>${s}</span>";
in

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      position = "top";
      height = 30;
      spacing = 2;
      "modules-left" = [
        "sway/workspaces"
        "sway/scratchpad"
        "sway/mode"
      ];
      "modules-center" = [
        "custom/countdown-control"
        "custom/countdown"
      ];
      "modules-right" = [
        "group/status"
        "clock"
        "custom/status-divider"
        "tray"
        "custom/tray-divider"
        "custom/power-menu"
      ];
      "group/status" = {
        orientation = "horizontal";
        modules = [
          "custom/inhibit"
          "bluetooth"
          "network"
          "pulseaudio"
          "power-profiles-daemon"
          "battery"
        ];
      };
      network = {
        interval = 5;
        "on-click" = "foot --app-id=wifitui -T 'Wi-Fi' wifitui";
        format-wifi = "${faSpan ""} {signalStrength}%";
        format-ethernet = "${faSpan ""} LAN";
        format-disconnected = faSpan "";
        format-disabled = faSpan "";
        tooltip-format-wifi = "SSID: {essid}\nSignal: {signalStrength}%\nIP: {ipaddr}/{cidr}\nGateway: {gwaddr}";
        tooltip-format-ethernet = "Interface: {ifname}\nIP: {ipaddr}/{cidr}\nGateway: {gwaddr}";
        tooltip-format-disconnected = "Network disconnected";
        tooltip-format-disabled = "Wi-Fi disabled";
      };
      bluetooth = {
        format = faSpan "";
        "format-disabled" = "${faSpan ""} Disabled";
        "format-off" = "${faSpan ""} Off";
        "format-on" = "${faSpan ""} On";
        "format-connected" = faSpan "";
        "format-no-controller" = "${faSpan ""} N/A";
        tooltip = true;
        "tooltip-format" = "{controller_alias}: {status}";
        "tooltip-format-connected" = "{controller_alias} · {num_connections} connected\n{device_enumerate}";
        "tooltip-format-enumerate-connected" = "{device_alias}";
        "on-click" = "foot --app-id=bluetui -T Bluetooth bluetui";
      };
      # Keep all five workspaces visible.
      "sway/workspaces" = {
        "disable-scroll" = true;
        "persistent-workspaces" = {
          "1" = [ ];
          "2" = [ ];
          "3" = [ ];
          "4" = [ ];
          "5" = [ ];
        };
      };
      # Show the indicator only while Sway has scratchpad windows.
      "sway/scratchpad" = {
        format = "${faSpan ""} {count}";
        "show-empty" = false;
        tooltip = true;
        "tooltip-format" = "{app}: {title}";
      };
      "custom/power-menu" = {
        format = faSpan "";
        tooltip = true;
        "tooltip-format" = "Power options";
        "on-click" = "~/.local/bin/utilities --power";
      };
      "custom/status-divider" = {
        format = " ";
        tooltip = false;
      };
      "custom/tray-divider" = {
        format = " ";
        tooltip = false;
      };
      pulseaudio = {
        format = "${faSpan "{icon}"} {volume}%";
        "format-muted" = "muted";
        "format-icons".default = [
          ""
          ""
          ""
        ];
        "on-click" = "foot --app-id=wiremix -T 'Audio' wiremix";
      };
      "power-profiles-daemon" = {
        format = faSpan "{icon}";
        tooltip = true;
        "tooltip-format" = "Power profile: {profile}";
        "on-click" = "~/.local/bin/power-profile-menu";
        "format-icons" = {
          performance = "";
          balanced = "";
          "power-saver" = "";
        };
      };
      battery = {
        states = {
          warning = 25;
          critical = 15;
        };
        format = "${faSpan "{icon}"} {capacity}%";
        "format-charging" = "${faSpan ""} {capacity}%";
        "format-plugged" = "${faSpan ""} {capacity}%";
        "format-icons" = [
          ""
          ""
          ""
          ""
          ""
        ];
      };
      "custom/countdown-control" = {
        exec = "~/.local/bin/countdown-engine status-control";
        signal = 10;
        interval = "once";
        "return-type" = "json";
        format = faSpan "{text}";
        escape = true;
        "on-click" = "~/.local/bin/countdown-engine control-click";
        "on-click-right" = "~/.local/bin/countdown";
      };
      "custom/countdown" = {
        exec = "~/.local/bin/countdown-engine status-time";
        signal = 8;
        return-type = "json";
        escape = true;
        "hide-empty-text" = true;
        "on-click" = "~/.local/bin/countdown-engine control-click";
        "on-click-right" = "~/.local/bin/countdown";
      };
      # Idle-inhibition status.
      "custom/inhibit" = {
        exec = "~/.local/bin/countdown-engine inhibit";
        # Escape markup in the tooltip.
        format = faSpan "{text}";
        escape = true;
        signal = 7;
        return-type = "json";
        "on-click" = "~/.local/bin/countdown-engine inhibit-toggle";
      };
      clock = {
        format = "{:%H:%M}";
        tooltip-format = "{:%d %B %Y}";
        locale = "en_US.UTF-8";
      };
      tray = {
        spacing = 10;
        "icon-size" = 16;
      };
    };
    style = ''
      /* Use JetBrains Mono for text; icons specify their own font. */
      * {
        font-family: "JetBrains Mono", "JetBrains Mono Nerd Font Mono", monospace;
        font-size: 13px;
        border: none;
        border-radius: 0;
      }

      /* A quiet, continuous Gruvbox bar with a thin lower edge. */
      @define-color txt ${theme.fg2};
      @define-color txt-strong ${theme.fg0};
      @define-color muted ${theme.gray};

      window#waybar {
        background: ${theme.bg0};
        color: @txt;
        border-bottom: 1px solid ${theme.bg2};
      }

      #workspaces,
      #scratchpad,
      #mode,
      #clock,
      #custom-power-menu {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0 4px;
        padding: 0 4px;
      }

      #workspaces { margin: 0 2px 0 4px; padding: 0; }
      #scratchpad { margin: 0 5px; padding: 0 2px; color: @txt; }
      #workspaces button {
        color: @txt;
        background: transparent;
        border: none;
        border-bottom: 2px solid transparent;
        border-radius: 0;
        box-shadow: none;
        min-width: 16px;
        margin: 0;
        padding: 0 4px;
        font-size: 15px;
        transition: none;
      }
      #workspaces button:hover {
        background: ${theme.bg1};
        box-shadow: none;
      }
      #workspaces button.focused, #workspaces button.active {
        color: @txt-strong;
        background: ${theme.bg2};
        border-bottom-color: ${theme.fg3};
      }
      /* Keep empty workspaces subdued while occupied ones use the default text color. */
      #workspaces button.persistent.empty { color: ${theme.bg4}; }
      #workspaces button.urgent { color: ${theme.orange}; border-bottom-color: ${theme.orange}; }
      /* Keep focused empty workspaces readable. */
      #workspaces button.persistent.empty.focused {
        color: @txt-strong;
        background: ${theme.bg2};
      }
      #status {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0;
        padding: 0;
      }
      box#status > widget > * {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0 4px;
        padding: 0 2px;
      }
      #custom-countdown-control { min-width: 18px; margin: 0; padding: 0; }
      #custom-countdown { min-width: 44px; margin: 0; padding: 0; }
      #clock { margin-left: 2px; margin-right: 2px; }
      #tray {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0;
        padding: 0 3px;
      }
      #mode { color: ${theme.blue}; }
      #custom-status-divider, #custom-tray-divider {
        border-left: 1px solid ${theme.bg3};
        min-height: 14px;
        margin: 0 1px;
        padding: 0;
      }
      #custom-power-menu { color: ${theme.fg2}; margin: 0 8px 0 2px; padding: 0 3px; }
      #custom-power-menu:hover { color: ${theme.fg0}; }
      #clock, #custom-countdown { font-weight: bold; }
      #custom-countdown.running { color: ${theme.blue}; }
      #custom-countdown.paused { color: ${theme.orange}; }
      #custom-countdown.idle { color: @muted; }
      #custom-countdown-control.running { color: ${theme.blue}; }
      #custom-countdown-control.paused { color: ${theme.orange}; }
      #custom-countdown-control.idle { color: @muted; }
      #custom-inhibit.idle { color: @muted; }
      #bluetooth.off, #bluetooth.disabled, #bluetooth.no-controller { color: @muted; }
      #bluetooth.connected { color: ${theme.green}; }
      #network.disconnected, #network.disabled { color: @muted; }
      #battery.warning { color: ${theme.yellow}; }
      #battery.critical { color: ${theme.red}; }
      #battery.charging { color: ${theme.green}; font-weight: bold; }
      #battery.plugged { color: ${theme.green}; }
      #pulseaudio.muted { color: @muted; }
    '';
  };
}
