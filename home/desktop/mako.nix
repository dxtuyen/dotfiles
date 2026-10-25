{ pkgs, ... }:

let
  theme = import ../theme.nix;
  iconTheme = import ./icon-theme.nix { inherit pkgs; };
in

{
  services.mako = {
    enable = true;

    settings = {
      # Mako does not follow Inherits from index.theme; list Gruvbox Plus'
      # Breeze-Dark and hicolor parents explicitly for notification fallbacks.
      icon-path = builtins.concatStringsSep ":" [
        "${iconTheme.package}/share/icons/${iconTheme.name}"
        "${pkgs.kdePackages.breeze-icons}/share/icons/breeze-dark"
        "${pkgs.hicolor-icon-theme}/share/icons/hicolor"
      ];
      icons = 1;
      max-icon-size = 33;
      icon-location = "left";
      # Popup 350px wide, max 600px tall so long content is not cut off.
      margin = "35,20,20,20";
      width = 350;
      height = 600;
      default-timeout = 5000;
      background-color = theme.bg0;
      text-color = theme.fg1;
      border-color = theme.neutralBlue;
      border-radius = 8;
      # Per-app timeouts.
      # Translation auto-dismisses after ~2 min; left click dismisses early.
      "app-name=quick-lang".default-timeout = 120000;
      "app-name=quick-lang".border-color = theme.neutralBlue;
      # Left click dismisses the translation notification.
      "app-name=quick-lang".on-button-left = "dismiss";
      "app-name=volume".default-timeout = 2000;
      "app-name=brightness".default-timeout = 2000;
      "app-name=wlsunset".default-timeout = 2000;
      "app-name=power-profiles".default-timeout = 2000;
      "app-name=toggle-touchpad".default-timeout = 2000;
      # Countdown: border matches the Waybar clock color.
      "app-name=countdown".border-color = theme.neutralBlue;
      "app-name=countdown".default-timeout = 5000;
      "app-name=screenshot".default-timeout = 2000;
      "app-name=power".default-timeout = 2000;
    };
  };
}
