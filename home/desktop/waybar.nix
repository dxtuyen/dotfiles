{ config, ... }:

let
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
      spacing = 4;
      "modules-left" = [
        "sway/workspaces"
        "custom/away-windows"
        "sway/mode"
      ];
      "modules-center" = [
        "group/countdown"
        "clock"
      ];
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
      # Countdown control and menu time share one pill but keep separate clicks.
      "group/countdown" = {
        orientation = "horizontal";
        modules = [
          "custom/countdown-control"
          "custom/countdown"
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
      };
      "custom/countdown" = {
        exec = "~/.local/bin/countdown-engine status-time";
        signal = 8;
        return-type = "json";
        "hide-empty-text" = true;
        "on-click" = "~/.local/bin/countdown";
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
        format = "{:%I:%M %p}";
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
      * { font-family: "JetBrains Mono", "JetBrains Mono Nerd Font Mono", monospace; font-size: 13px; border: none; border-radius: 0; }

      /* Catppuccin colors for pills, text, and accents. */
      @define-color pill rgba(30, 30, 46, 0.80);   /* Catppuccin base */
      @define-color edge rgba(69, 71, 90, 0.45);    /* Catppuccin surface1 */
      @define-color txt #bac2de;                    /* Catppuccin subtext1 */
      @define-color txt-strong #cdd6f4;             /* Catppuccin text */
      @define-color muted #7f849c;                   /* Catppuccin overlay1 */

      window#waybar { background: rgba(0, 0, 0, 0); color: @txt; }
      #workspaces, #tray, #mode,
      #custom-away-windows, #clock, #countdown,
      #status {
        background: @pill;
        border: 1px solid @edge;
        border-radius: 10px;
        padding: 0 9px;
        margin: 4px 3px;
      }
      box#status > widget > *, box#countdown > widget > * {
        background: transparent;
        border: none;
        border-radius: 0;
        margin: 0;
        padding: 0 6px;
      }
      #workspaces { margin-left: 4px; padding: 0 10px; }
      #workspaces button { padding: 0 7px; color: @txt; font-size: 15px; border-bottom: 2px solid transparent;
        background-color: rgba(0, 0, 0, 0); }
      #workspaces button:hover, #workspaces button:active {
        background-color: rgba(0, 0, 0, 0); box-shadow: none; }
      #workspaces button.focused, #workspaces button.active {
        color: @txt-strong;
        background-color: rgba(137, 180, 250, 0.16);
        border-radius: 6px;
      }
      #workspaces button.urgent { color: #f38ba8; border-bottom-color: #f38ba8; }
      /* Dim empty workspaces. */
      #workspaces button.persistent.empty { color: #6c7086; }
      /* Keep the focused empty workspace highlighted. */
      #workspaces button.persistent.empty.focused { background-color: rgba(137, 180, 250, 0.16); }
      #tray { padding: 0 8px; }
      #mode { color: #89b4fa; }
      #clock, #countdown { font-weight: bold; }
      #custom-countdown.running { color: #89b4fa; }
      #custom-countdown.paused { color: #fab387; }
      #custom-countdown.idle { color: @muted; }
      #custom-countdown-control.running { color: #89b4fa; }
      #custom-countdown-control.paused { color: #fab387; }
      #custom-countdown-control.idle { color: @muted; }
      #custom-inhibit.running { color: #89b4fa; }
      #custom-inhibit.manual { color: #fab387; }
      #custom-inhibit.idle { color: @muted; }
      #bluetooth.off, #bluetooth.disabled, #bluetooth.no-controller { color: @muted; }
      #bluetooth.connected { color: #a6e3a1; }
      #network.disconnected, #network.disabled { color: #f38ba8; }
      #battery.warning { color: #fab387; }
      #battery.critical { color: #f38ba8; }
      #battery.charging { color: #a6e3a1; font-weight: bold; }
      #battery.plugged { color: #a6e3a1; }
      #pulseaudio.muted { color: @muted; }
    '';
  };
}
