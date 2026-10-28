{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    # Keep GUI-installed extensions and merge just these appearance preferences.
    mutableExtensionsDir = true;
    profiles.default = {
      mutableUserSettings = true;
      extensions = [ pkgs.vscode-extensions.sainnhe.gruvbox-material ];
      userSettings = {
        "workbench.colorTheme" = "Gruvbox Material Dark";
        "workbench.preferredDarkColorTheme" = "Gruvbox Material Dark";
        "gruvboxMaterial.darkContrast" = "medium";
        "gruvboxMaterial.darkPalette" = "material";
        "gruvboxMaterial.darkWorkbench" = "material";
      };
    };
  };
}
