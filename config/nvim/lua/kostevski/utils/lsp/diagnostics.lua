local M = {}

M.signs = {
   Error = " ",
   Warn = " ",
   Hint = " ",
   Info = " ",
}

function M.setup()
   -- Configure diagnostic signs
   for type, icon in pairs(M.signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
   end

   -- Configure diagnostic display
   vim.diagnostic.config({
      virtual_text = {
         prefix = "●",
         source = "if_many",
         severity = {
            min = vim.diagnostic.severity.HINT,
         },
      },
      float = {
         source = "always",
         border = "rounded",
         header = "",
         prefix = "",
      },
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
   })
end

return M
