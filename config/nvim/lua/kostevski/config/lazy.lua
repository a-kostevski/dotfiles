local M = {}

function M.setup()
   local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

   -- Bootstrap lazy.nvim
   if not vim.uv.fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      vim.notify("Installing lazy.nvim...", vim.log.levels.INFO)
      local out = vim.fn.system({
         "git",
         "clone",
         "--filter=blob:none",
         "--branch=stable",
         lazyrepo,
         lazypath,
      })
      if vim.v.shell_error ~= 0 then
         vim.notify("Failed to install lazy.nvim:\n" .. out, vim.log.levels.ERROR)
         return false
      end
   end

   vim.opt.rtp:prepend(lazypath)

   -- Setup lazy.nvim
   require("lazy").setup({
      spec = {
         { import = "kostevski.plugins" },
         -- coding/ui/editor/lsp/tools subtrees load via their own
         -- <category>.lua self-imports; only lang/ has no category file.
         { import = "kostevski.plugins.lang" },
      },
      defaults = {
         lazy = true,
         version = false,
      },
      checker = {
         enabled = true,
         notify = false,
         frequency = 86400, -- Check for updates every day
      },
      change_detection = {
         enabled = true,
         notify = false,
      },
      performance = {
         cache = {
            enabled = true,
         },
         reset_packpath = true,
         rtp = {
            reset = true,
            disabled_plugins = {
               "gzip",
               "tarPlugin",
               "tohtml",
               "tutor",
               "zipPlugin",
               "2html_plugin",
               "matchit",
            },
         },
      },
   })

   return true
end

return M
