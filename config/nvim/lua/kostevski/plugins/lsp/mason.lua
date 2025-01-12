return {
   "williamboman/mason.nvim",
   name = "mason",
   build = ":MasonUpdate",
   opts_extend = { "ensure_installed" },
   dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
   },
   main = true,
   opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
         "bashls",
         "lua_ls",
         "luacheck",
         "shellcheck",
         "stylua",
      })
   end,
   config = function(_, opts)
      require("mason").setup(opts)
      Utils.debug.dump(opts)
      require("mason-lspconfig").setup({})
      require("mason-tool-installer").setup({
         ensure_installed = opts.ensure_installed,
      })
   end,
}
