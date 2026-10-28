{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    plugins = [ pkgs.vimPlugins.gruvbox-material ];
    extraConfig = ''
      set termguicolors
      set background=dark
      let g:gruvbox_material_background = 'medium'
      let g:gruvbox_material_foreground = 'material'
      let g:gruvbox_material_better_performance = 1
      colorscheme gruvbox-material
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
