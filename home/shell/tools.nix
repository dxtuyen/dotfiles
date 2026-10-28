{ ... }:

let
  theme = import ../theme.nix;
in
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      bg = theme.bg0;
      fg = theme.fg1;
      "bg+" = theme.selection;
      "fg+" = theme.fg0;
      hl = theme.yellow;
      "hl+" = theme.yellow;
      info = theme.aqua;
      prompt = theme.blue;
      pointer = theme.orange;
      marker = theme.green;
      spinner = theme.purple;
      header = theme.gray;
      border = theme.bg4;
    };
  };
}
