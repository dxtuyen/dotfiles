{ config, pkgs, ... }:

let
  # Keep editable Lua and LazyVim's writable state in the dotfiles checkout.
  nvimConfig = "${config.home.homeDirectory}/dotfiles/home/programs/neovim";
  linkConfig = name: {
    source = config.lib.file.mkOutOfStoreSymlink "${nvimConfig}/${name}";
  };
in

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # Home Manager owns init.lua; lazy.nvim owns the plugin lifecycle.
    initLua = builtins.readFile ./neovim/init.lua;
    extraPackages = with pkgs; [
      tree-sitter
      lazygit
      nil
      nixfmt
      statix
      lua-language-server
      stylua
      bash-language-server
      shfmt
      shellcheck
    ];
  };

  xdg.configFile = {
    "nvim/lua" = linkConfig "lua";
    "nvim/lazy-lock.json" = linkConfig "lazy-lock.json";
    "nvim/lazyvim.json" = linkConfig "lazyvim.json";
    "nvim/stylua.toml" = linkConfig "stylua.toml";
  };
}
