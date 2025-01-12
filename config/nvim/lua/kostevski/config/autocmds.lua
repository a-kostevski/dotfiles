local function augroup(name)
   return vim.api.nvim_create_augroup("my_" .. name, { clear = true })
end

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
   desc = "Highlight when yanking (copying) text",
   group = augroup("highlight-yank"),
   callback = function()
      vim.highlight.on_yank()
   end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
   group = augroup("close_with_q"),
   pattern = {
      "grug-far",
      "help",
      "lspinfo",
      "notify",
      "tsplayground",
      "checkhealth",
   },
   callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.keymap.set("n", "q", "<cmd>close<cr>", {
         buffer = event.buf,
         silent = true,
         desc = "Quit buffer",
      })
   end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd("FileType", {
   group = augroup("man_unlisted"),
   pattern = { "man" },
   callback = function(event)
      vim.bo[event.buf].buflisted = false
   end,
})

-- vim.api.nvim_create_autocmd("FileType", {
--    group = augroup("markdown-editor"),
--    pattern = { "markdown" },
--    callback = function(event)
--       require("no-neck-pain").enable()
--    end,
-- })
