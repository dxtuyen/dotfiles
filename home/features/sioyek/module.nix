{ lib, userName, ... }:

let
  theme = import ../../theme.nix;
  # Sioyek expects RGB components in [0,1], rather than hex strings.
  rgb =
    color:
    lib.concatStringsSep " " (
      map (offset: toString ((lib.fromHexString (builtins.substring offset 2 color)) / 255.0)) [
        1
        3
        5
      ]
    );
in
{
  # Each new file = a separate window (still 1 process); new windows appear on the
  # focused workspace via the for_window rule in home/desktop/sway.nix.
  xdg.configFile."sioyek/prefs_user.config".text = ''
    should_launch_new_window 1
    background_color ${rgb theme.bg0}
    dark_mode_background_color ${rgb theme.bg0}
    custom_color_mode_empty_background_color ${rgb theme.bg0}
    custom_background_color ${rgb theme.bg0}
    custom_text_color ${rgb theme.fg1}
    ui_background_color ${rgb theme.bg1}
    ui_text_color ${rgb theme.fg1}
    ui_selected_background_color ${rgb theme.selection}
    ui_selected_text_color ${rgb theme.fg0}
    status_bar_color ${rgb theme.bg1}
    status_bar_text_color ${rgb theme.fg1}
    page_separator_color ${rgb theme.bg3}
    text_highlight_color ${rgb theme.yellow}
    search_highlight_color ${rgb theme.green}
    link_highlight_color ${rgb theme.blue}
    synctex_highlight_color ${rgb theme.purple}
    # Keep PDF page colors intact (figures/scans); custom colors are available
    # with Sioyek's toggle_custom_color command when reading plain text.
  '';

  # All PDF open paths go through sioyek-open (apps cannot focus themselves on Wayland).
  xdg.desktopEntries.sioyek = {
    type = "Application";
    name = "Sioyek";
    comment = "PDF viewer for reading research papers and technical books";
    # Absolute path (the sway session has no ~/.local/bin in PATH).
    exec = "/home/${userName}/.local/bin/sioyek-open %f";
    icon = "sioyek-icon-linux";
    categories = [
      "Development"
      "Viewer"
    ];
    terminal = false;
    startupNotify = true;
    settings = {
      StartupWMClass = "sioyek";
      # Declare only `settings`, NOT `mimeType` (the module translates it into
      # `extraConfig` — the option was removed in HM 26.05 -> no file is generated).
      MimeType = "application/pdf;";
    };
  };
}
