require("kostevski.utils.root").add_patterns("json", {
   "package.json",
   "tsconfig.json",
})

return {
   {
      "b0o/SchemaStore.nvim",
      lazy = true,
      version = false,
   },
   -- LSP Configuration
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

   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            json = { "jq" },
            jsonc = { "jq" },
         },
      },
   },

   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "json", "jsonc" })
         end
      end,
   },
}
