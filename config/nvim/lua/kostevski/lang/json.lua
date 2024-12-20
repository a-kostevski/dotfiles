return {
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         vim.list_extend(opts.ensure_installed, {
            ensure_installed = {
               "json",
               "jsonc",
            },
         })
      end,
   },

   {
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
            "jsonls",
         })
      end,
   },
   {
      "b0o/schemastore.nvim",
      lazy = true,
      version = false,
   },
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            jsonls = {
               on_new_config = function(new_config)
                  new_config.settings.json.schemas = new_config.settings.json.schemas or {}
                  vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
               end,
               settings = {
                  json = {
                     format = {
                        enable = true,
                     },
                     validate = { enable = true },
                  },
               },
            },
         },
      },
   },
}
