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
