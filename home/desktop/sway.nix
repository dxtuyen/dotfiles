{ config, pkgs, ... }:

let
  theme = import ../theme.nix;
in

{
  wayland.windowManager.sway = {
    enable = true;
    package = null; # use Sway from the NixOS module
    config = null; # configure everything via extraConfig
    systemd.enable = true;

    extraConfig = ''
      # Export the Sway session environment to systemd and D-Bus.
      exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway SWAYSOCK XMODIFIERS QT_IM_MODULE
      exec systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK XMODIFIERS QT_IM_MODULE

      exec systemctl --user start sway-session.target

      set $mod Mod4
      set $left h
      set $down j
      set $up k
      set $right l
      set $term foot
      set $menu rofi -show drun

      # Applets & daemons
      exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
      # Restore the selected night light mode.
      exec ~/.local/bin/wlsunset-apply

      input type:touchpad {
        pointer_accel 0.6
        accel_profile adaptive
        natural_scroll enabled
        scroll_method two_finger
        tap enabled
        drag enabled
        dwt enabled
      }
      # Keep the physical layout explicit; Fcitx handles Vietnamese input separately.
      input type:keyboard {
        xkb_layout us
      }
      seat * hide_cursor 10000
      seat * xcursor_theme Bibata-Modern-Classic 24

      # Gruvbox Dark styling
      gaps inner 5
      gaps outer 3
      gaps top 0
      default_border pixel 2
      default_floating_border pixel 2
      # $mod + left/right mouse button = move/resize floating windows.
      floating_modifier $mod normal
      focus_follows_mouse yes
      # Keep Sway's default activation behavior: mark requests urgent without stealing focus.
      smart_borders off

      # Keep the focused border at light3; use a nearby muted ochre for the split indicator.
      client.focused           ${theme.fg3} ${theme.bg1} ${theme.fg0} ${theme.splitIndicator} ${theme.fg3}
      client.focused_inactive  ${theme.bg3} ${theme.bg0} ${theme.fg1} ${theme.bg3} ${theme.bg3}
      client.unfocused         ${theme.bg2} ${theme.bg0} ${theme.fg3} ${theme.bg2} ${theme.bg2}
      client.urgent            ${theme.orange} ${theme.bg0} ${theme.orange} ${theme.bg3} ${theme.orange}
      client.placeholder       ${theme.bg0} ${theme.bg0} ${theme.fg1} ${theme.bg3} ${theme.bg3}
      client.background        ${theme.bg0}

      # Floating rules
      # Keep the popup terminal at Foot's default size, as before.
      for_window [app_id="scratchpad-terminal"] move scratchpad, scratchpad show
      # WireMix runs inside Foot; keep the audio mixer in a compact floating window.
      for_window [app_id="wiremix"] floating enable, resize set width 50 ppt height 60 ppt
      for_window [app_id="bluetui"] floating enable, resize set 750 px 500 px
      for_window [title="htop"] floating enable, resize set width 50 ppt height 70 ppt

      # GoldenDict popup; Mod+g toggles it and closing hides it to the tray.
      for_window [app_id="io.github.xiaoyifang.goldendict_ng"] floating enable, resize set width 50 ppt height 65 ppt
      # Sioyek: new windows open on the focused workspace.
      for_window [app_id="(?i)^sioyek$"] move container to workspace current

      # Move Anki to workspace 5 and switch there when it opens.
      for_window [app_id="(?i)^anki$"] move container to workspace number 5, workspace number 5, focus
      for_window [class="(?i)^anki$"] move container to workspace number 5, workspace number 5, focus

      # Open Foliate on the currently focused workspace.
      for_window [app_id="(?i)^com\.github\.johnfactotum\.foliate$"] move container to workspace current

      # Thunar popup; Mod+Shift+Space toggles it back to tiling.
      for_window [app_id="(?i)^thunar$"] floating enable, resize set width 40 ppt height 65 ppt

      # Wi-Fi popup.
      for_window [app_id="wifitui"] floating enable, resize set 750 px 500 px

      # Dialog/popup rules
      for_window [window_role="pop-up"] floating enable
      for_window [window_role="bubble"] floating enable
      for_window [window_role="task_dialog"] floating enable
      for_window [window_role="Preferences"] floating enable
      for_window [window_type="dialog"] floating enable
      for_window [window_type="menu"] floating enable
      for_window [window_role="About"] floating enable
      for_window [title="Save File"] floating enable

      # Center file choosers opened by xdg-desktop-portal-gtk.
      for_window [app_id="(?i)^xdg-desktop-portal-gtk$"] floating enable, move position center

      # Chrome Picture-in-Picture
      for_window [title="Picture in picture"] floating enable, sticky enable, resize set width 350 px height 197 px, move position 1530 px 800 px

      # Inhibit idle
      for_window [app_id="(?i)^google-chrome$"] inhibit_idle fullscreen

      # Keybindings - App & Session
      bindsym $mod+Return exec $term
      bindsym $mod+grave exec ~/.local/bin/scratchpad-terminal
      bindsym $mod+d exec $menu
      # Alt+Tab toggles between the current and previously focused workspace.
      # Mod+u opens utilities; Mod+p and the Waybar power button open power actions.
      # Mod+c opens Countdown.
      bindsym Mod1+Tab workspace back_and_forth
      # Toggle Sway's native scratchpad; Shift+Mod+- sends the focused window there.
      bindsym $mod+minus scratchpad show
      bindsym $mod+Shift+minus move scratchpad
      # Mod+Tab opens the Sway workspace overview.
      bindsym $mod+Tab exec pkill -x swayview || swayview
      bindsym $mod+q kill

      bindsym $mod+Shift+c exec ~/.local/bin/refresh-session
      bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit Sway?' -B 'Yes, exit sway' 'swaymsg exit'
      bindsym $mod+c exec ~/.local/bin/countdown
      # Focus movement
      bindsym $mod+$left focus left
      bindsym $mod+$down focus down
      bindsym $mod+$up focus up
      bindsym $mod+$right focus right
      bindsym $mod+Left focus left
      bindsym $mod+Down focus down
      bindsym $mod+Up focus up
      bindsym $mod+Right focus right

      # Container movement
      bindsym $mod+Shift+$left move left
      bindsym $mod+Shift+$down move down
      bindsym $mod+Shift+$up move up
      bindsym $mod+Shift+$right move right
      bindsym $mod+Shift+Left move left
      bindsym $mod+Shift+Down move down
      bindsym $mod+Shift+Up move up
      bindsym $mod+Shift+Right move right

      # Five numbered workspaces, matching the Waybar configuration.
      bindsym $mod+1 workspace number 1
      bindsym $mod+Shift+1 move container to workspace number 1
      bindsym $mod+2 workspace number 2
      bindsym $mod+Shift+2 move container to workspace number 2
      bindsym $mod+3 workspace number 3
      bindsym $mod+Shift+3 move container to workspace number 3
      bindsym $mod+4 workspace number 4
      bindsym $mod+Shift+4 move container to workspace number 4
      bindsym $mod+5 workspace number 5
      bindsym $mod+Shift+5 move container to workspace number 5
      # Cycle through workspaces; Shift moves the focused window.
      bindsym $mod+bracketleft workspace prev
            bindsym $mod+bracketright workspace next
            bindsym $mod+Shift+bracketleft move container to workspace prev
            bindsym $mod+Shift+bracketright move container to workspace next
      # Layout & Window State
      bindsym $mod+b splith
      bindsym $mod+v splitv
      bindsym $mod+s layout stacking
      bindsym $mod+w layout tabbed
      bindsym $mod+e layout toggle split
      bindsym $mod+f fullscreen
      bindsym $mod+Shift+space floating toggle
      bindsym $mod+space focus mode_toggle
      bindsym $mod+a focus parent
      bindsym $mod+Shift+a focus child
      # Enter Sway's native resize mode.
      bindsym $mod+r mode "resize"

      mode "resize" {
        bindsym $left resize shrink width 10 px or 10 ppt
        bindsym $down resize grow height 10 px or 10 ppt
        bindsym $up resize shrink height 10 px or 10 ppt
        bindsym $right resize grow width 10 px or 10 ppt
        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt
        bindsym Return mode "default"
        bindsym Escape mode "default"
      }

      # Custom Utilities & Screenshot
      # Toggle Waybar visibility (SIGUSR1 toggles it by default).
      bindsym $mod+Shift+b exec systemctl --user kill --signal=SIGUSR1 --kill-whom=main waybar.service
      # Mod+u opens daily utilities; Mod+p and the Waybar power button open session and power actions.
      bindsym $mod+u exec ~/.local/bin/utilities
      bindsym $mod+p exec ~/.local/bin/utilities --power
      bindsym $mod+Escape exec ~/.local/bin/lock-screen
      # Quick language tools: Mod+t translates Vietnamese to English; Shift reverses it;
      # Ctrl+t fixes English. Optional context prefixes: [phi], [sci], [lit], [cas].
      bindsym $mod+t exec ~/.local/bin/quick-lang vi-en
      bindsym $mod+Shift+t exec ~/.local/bin/quick-lang en-vi
      bindsym $mod+Ctrl+t exec ~/.local/bin/quick-lang fix
      # Toggle the GoldenDict popup; closing it hides it to the tray.
      bindsym $mod+g exec ~/.local/bin/dict-toggle
      bindsym $mod+Mod1+t exec ~/.local/bin/toggle-touchpad
      bindsym $mod+Print exec ~/.local/bin/screenshot-menu
      bindsym --no-repeat Print exec ~/.local/bin/screenshot selection-clipboard
      bindsym --no-repeat Mod1+Print exec ~/.local/bin/screenshot fullscreen-clipboard
      bindsym --no-repeat Shift+Print exec ~/.local/bin/screenshot selection-save
      bindsym --no-repeat Ctrl+Print exec ~/.local/bin/screenshot fullscreen-save

      # Media & Brightness keys
      bindsym XF86AudioRaiseVolume exec ~/.local/bin/media-notify volume-up
      bindsym XF86AudioLowerVolume exec ~/.local/bin/media-notify volume-down
      bindsym XF86AudioMute exec ~/.local/bin/media-notify volume-mute
      bindsym XF86AudioMicMute exec ~/.local/bin/media-notify mic-mute
      bindsym XF86MonBrightnessUp exec ~/.local/bin/media-notify brightness-up
      bindsym XF86MonBrightnessDown exec ~/.local/bin/media-notify brightness-down

      # Lock after 300s, turn off the display after 310s, and suspend after 900s on battery.
      # Countdown temporarily stops and restarts this service.
    '';
  };

  # Run swayidle with logging, crash recovery, and Sway-session lifecycle management.
  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager for Wayland (lock → screen off → suspend)";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "simple";
      # Replace stale instances without stopping Countdown's separate lock handler.
      ExecStartPre = "-${pkgs.procps}/bin/pkill -f 'swayidle -w timeout 300'";
      # Commands started by swayidle need these tools on PATH.
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout 300 '%h/.local/bin/lock-screen' \
          timeout 310 'swaymsg "output * power off"' \
          resume 'swaymsg "output * power on"' \
          timeout 900 '%h/.local/bin/idle-suspend' \
          before-sleep '%h/.local/bin/lock-screen' \
          after-resume 'swaymsg "output * power on"' \
          lock '%h/.local/bin/lock-screen' \
          unlock 'swaymsg "output * power on"'
      '';
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
}
