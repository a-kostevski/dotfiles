vim.api.nvim_create_autocmd("FileType", {
   pattern = { "tex", "plaintex" },
   callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.spell = true
      vim.opt_local.textwidth = 80
   end,
})
return {}
