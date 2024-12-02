local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
   local lazyrepo = "https://github.com/folke/lazy.nvim.git"
   local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
   if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo(
         { { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" }, { "\nPress any key to exit..." } },
         true,
         {}
      )
      vim.fn.getchar()
      os.exit(1)
   end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
   spec = {
      { import = "kostevski.plugins" },
      { import = "kostevski.lang" },
   },
   defaults = {
      lazy = false,
      version = false,
   },
   install = {
      colorscheme = { "catppuccin" },
   },
   checker = {
      enabled = true,
      notify = false,
   },
   change_detection = {
      enabled = false,
   },
   news = {
      lazyvim = true,
      neovim = true,
   },
   performance = {
      cache = {
         enabled = true,
      },
      rtp = {
         disabled_plugins = {
            "gzip",
            "tarPluin",
            "tohtml",
            "tutor",
            "zipPlugin",
            "2html_plugin",
         },
      },
   },
})
