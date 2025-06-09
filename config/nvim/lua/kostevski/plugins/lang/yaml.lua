return {
   {
      "b0o/SchemaStore.nvim",
      lazy = true,
      version = false,
      config = function()
         vim.lsp.config("yamlls", {
            capabilities = {
               textDocument = {
                  foldingRange = {
                     dynamicRegistration = false,
                     lineFoldingOnly = true,
                  },
               },
            },
         })
      end,
   },
}
