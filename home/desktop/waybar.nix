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
        "custom/away-windows"
        "sway/mode"
      ];
      "modules-center" = [ "group/countdown" ];
      "modules-right" = [
        "group/status"
        "tray"
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
      # Reuse the Mod+= list for both the label and tooltip.
      "custom/away-windows" = {
        "exec" = "~/.local/bin/window-menu --away --waybar";
        "return-type" = "json";
        "interval" = "once";
        # The Sway event listener refreshes this module immediately.
        "signal" = 9;
        "format" = "${faSpan ""} {text}";
        "max-length" = 42;
        "hide-empty-text" = true;
        "escape" = true;
        "on-click" = "~/.local/bin/window-menu --away";
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
      # Keep the Pomodoro controls and clock together as one centered pair.
      "group/countdown" = {
        orientation = "horizontal";
        modules = [
          "custom/countdown-control"
          "custom/countdown"
          "clock"
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
      #custom-away-windows,
      #mode,
      #countdown,
      #status,
      #clock,
      #tray {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0 4px;
        padding: 0 5px;
      }

      #workspaces { margin-left: 8px; padding: 0; }
      #workspaces button {
        color: @txt;
        background: transparent;
        border: none;
        border-bottom: 2px solid transparent;
        border-radius: 0;
        box-shadow: none;
        padding: 0 8px;
        font-size: 15px;
        transition: none;
      }
      #workspaces button:hover {
        background: ${theme.bg1};
        box-shadow: none;
      }
      #workspaces button.focused, #workspaces button.active {
        color: @txt-strong;
        background-color: ${theme.focusHighlight};
        border-bottom-color: ${theme.neutralYellow};
      }
      #workspaces button.urgent { color: ${theme.neutralOrange}; border-bottom-color: ${theme.neutralOrange}; }
      /* Keep empty workspaces quiet but readable against the dark bar. */
      #workspaces button.persistent.empty { color: ${theme.gray}; }
      /* Keep the focused empty workspace highlighted. */
      #workspaces button.persistent.empty.focused {
        color: @txt-strong;
        background-color: ${theme.focusHighlight};
      }
      box#status > widget > *, box#countdown > widget > * {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0 2px;
        padding: 0 3px;
      }
      #countdown, #clock, #status, #tray { margin-left: 2px; margin-right: 2px; }
      #tray { margin-right: 8px; padding: 0 4px; }
      #mode { color: ${theme.blue}; }
      #clock, #countdown { font-weight: bold; }
      #custom-countdown.running { color: ${theme.blue}; }
      #custom-countdown.paused { color: ${theme.orange}; }
      #custom-countdown.idle { color: @muted; }
      #custom-countdown-control.running { color: ${theme.blue}; }
      #custom-countdown-control.paused { color: ${theme.orange}; }
      #custom-countdown-control.idle { color: @muted; }
      #custom-inhibit.running { color: ${theme.blue}; }
      #custom-inhibit.manual { color: ${theme.orange}; }
      #custom-inhibit.idle { color: @muted; }
      #bluetooth.off, #bluetooth.disabled, #bluetooth.no-controller { color: @muted; }
      #bluetooth.connected { color: ${theme.green}; }
      #network.disconnected, #network.disabled { color: ${theme.red}; }
      #battery.warning { color: ${theme.yellow}; }
      #battery.critical { color: ${theme.red}; }
      #battery.charging { color: ${theme.green}; font-weight: bold; }
      #battery.plugged { color: ${theme.green}; }
      #pulseaudio.muted { color: @muted; }
    '';
  };
}
