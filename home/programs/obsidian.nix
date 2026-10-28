{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Use the existing community theme directly, pinned for reproducible builds.
  materialTheme = pkgs.fetchFromGitHub {
    owner = "AllJavi";
    repo = "material_gruvbox_obsidian";
    rev = "35b5bc1d7f857cecfc87bab4bfe74e3de11f4d11";
    hash = "sha256-Ys7/hAAa04TnPraQT42gzMOmgjdov4CBWj7hlsDkBv8=";
  };
in
{
  # Discover registered vaults instead of hardcoding personal note paths. The
  # installer only copies upstream theme files and merges appearance settings.
  home.activation.obsidianMaterial = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python ${./obsidian-theme.py} \
      ${lib.escapeShellArg "${config.xdg.configHome}/obsidian/obsidian.json"} ${materialTheme}
  '';
}
