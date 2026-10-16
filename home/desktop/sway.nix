{ config, pkgs, ... }:

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

      # Choose a different random wallpaper when Sway starts.
      exec ~/.local/bin/wallpaper-set

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
      seat * hide_cursor 10000
      seat * xcursor_theme Bibata-Modern-Classic 24

      # Catppuccin Mocha styling
      gaps inner 7
      gaps outer 4
      gaps top 0
      default_border pixel 2
      default_floating_border pixel 2
      # $mod + left/right mouse button = move/resize floating windows.
      floating_modifier $mod normal
      focus_follows_mouse yes
      # Keep Sway's default activation behavior: mark requests urgent without stealing focus.
      smart_borders off

      # Use a bright blue border for the focused window and muted borders elsewhere.
      client.focused           #89b4fa #313244 #cdd6f4 #cba6f7 #89b4fa
      client.focused_inactive  #6c7086 #1e1e2e #cdd6f4 #6c7086 #6c7086
      client.unfocused         #585b70 #1e1e2e #6c7086 #585b70 #585b70
      client.urgent            #fab387 #1e1e2e #fab387 #6c7086 #fab387
      client.placeholder       #1e1e2e #1e1e2e #cdd6f4 #6c7086 #6c7086
      client.background        #1e1e2e

      # Floating rules
      # WireMix runs inside Foot; keep the audio mixer in a compact floating window.
      for_window [app_id="wiremix"] floating enable, resize set width 50 ppt height 60 ppt
      for_window [app_id="bluetui"] floating enable, resize set 750 px 500 px
      # Match common Obsidian app_id variants across package formats.
      for_window [app_id="(?i)^(md([.]obsidian)?[.]obsidian|obsidian)$"] floating enable, resize set width 1000 px height 700 px, move position center
      for_window [title="htop"] floating enable, resize set width 50 ppt height 70 ppt

      # GoldenDict popup; Mod+g toggles it and closing hides it to the tray.
      for_window [app_id="io.github.xiaoyifang.goldendict_ng"] floating enable, resize set width 50 ppt height 65 ppt
      # Sioyek: new windows open on the focused workspace.
      for_window [app_id="(?i)^sioyek$"] move container to workspace current

      # Open Foliate on the currently focused workspace.
      for_window [app_id="(?i)^com\.github\.johnfactotum\.foliate$"] move container to workspace current

      # Thunar popup; Mod+Shift+Space toggles it back to tiling.
      for_window [app_id="(?i)^thunar$"] floating enable, resize set width 40 ppt height 65 ppt

      # Yazi popup, toggled with Mod+y. Popup keys can hide or restore it.
      for_window [app_id="(?i)^yazi-popup$"] floating enable, resize set 1000 px 700 px

      # Keep the shell session alive while the terminal is hidden in the scratchpad.
      for_window [app_id="scratchpad-terminal"] move scratchpad, scratchpad show

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

      # Center Chrome PWAs from the Default profile. Add another profile suffix if needed.
      for_window [app_id="(?i)^chrome-[a-z0-9]+-Default$"] floating enable, resize set width 1000 px height 700 px, move position center

      # Inhibit idle
      for_window [app_id="(?i)^google-chrome$"] inhibit_idle fullscreen

      # Keybindings - App & Session
      bindsym $mod+Return exec $term
      # Toggle the persistent scratchpad terminal.
      bindsym $mod+grave exec ~/.local/bin/scratchpad-terminal
      bindsym $mod+d exec $menu
      # Alt+Tab switches to the urgent or most recently used window.
      # Mod+p opens utilities; Mod+c starts Countdown; Mod+q closes the focused window.
      bindsym Mod1+Tab exec ${pkgs.swayr}/bin/swayr switch-to-urgent-or-lru-window
      # Toggle Sway's workspace overview and switcher.
      bindsym $mod+Tab exec pkill -x swayview || swayview
      bindsym $mod+q kill

      # Mod+r selects a random wallpaper; Mod+Shift+w opens the wallpaper menu.
      bindsym $mod+r exec ~/.local/bin/wallpaper-set
      bindsym $mod+Shift+w exec ~/.local/bin/wallpaper-menu
      # Toggle the Yazi popup.
      bindsym $mod+y exec ~/.local/bin/yazi-open
      bindsym $mod+Shift+c exec ~/.local/bin/refresh-session
      bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit Sway?' -B 'Yes, exit sway' 'swaymsg exit'
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
      bindsym $mod+minus move scratchpad
      # Minus stashes windows; Shift+Minus stashes floating windows on this workspace.
      bindsym $mod+Shift+minus [workspace=__focused__ floating app_id="(?i).*goldendict.*"] kill; [workspace=__focused__ floating] move container to scratchpad
      bindsym $mod+equal exec ~/.local/bin/window-menu --away --first
      bindsym $mod+m exec ~/.local/bin/window-menu --away

      # Custom Utilities & Screenshot
      # Toggle Waybar visibility (SIGUSR1 toggles it by default).
      bindsym $mod+Shift+b exec systemctl --user kill --signal=SIGUSR1 --kill-whom=main waybar.service
      # Mod+p opens daily utilities.
      bindsym $mod+p exec ~/.local/bin/utilities
      # Mod+Shift+p opens session and power actions.
      # Open Chrome from the app launcher or a link.
      bindsym $mod+c exec ~/.local/bin/countdown
      bindsym $mod+Shift+p exec ~/.local/bin/utilities --power
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

  # swayrd remains enabled for Alt+Tab.

  # Record window focus history for the Sway session.
  systemd.user.services.swayrd = {
    Unit = {
      Description = "Swayr window history daemon";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.swayr}/bin/swayrd";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "sway-session.target" ];
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
