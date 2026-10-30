return {
  -- Executables come from programs.neovim.extraPackages, managed by Nix.
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { mason = false },
        nil_ls = { mason = false },
        bashls = { mason = false },
      },
    },
  },
}
