return {
   "williamboman/mason.nvim",
   name = "mason",
   build = ":MasonUpdate",
   opts_extend = { "ensure_installed" },
   dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
   },

   opts = {
      ensure_installed = {
         "bashls",
         "lua_ls",
         "luacheck",
         "stylua",
         "shfmt",
      },
   },

   config = function(_, opts)
      require("mason").setup(opts)
      require("mason-lspconfig").setup({})
      require("mason-tool-installer").setup({
         ensure_installed = opts.ensure_installed,
      })
   end,
}
