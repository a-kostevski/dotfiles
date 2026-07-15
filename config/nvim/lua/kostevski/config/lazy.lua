local M = {}

function M.setup()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  local LAZY_REVISION = "85c7ff3711b730b4030d03144f6db6375044ae82"
  local offline = vim.env.DOTFILES_NVIM_OFFLINE == "1"

  -- Bootstrap lazy.nvim (pin verified only at install time; no git calls on
  -- normal startups once the install exists)
  if not vim.uv.fs_stat(lazypath) then
    assert(not offline, "lazy.nvim is absent in offline mode; run :Lazy restore first")
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    vim.notify("Installing lazy.nvim...", vim.log.levels.INFO)
    local out = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      lazyrepo,
      lazypath,
    })
    if vim.v.shell_error ~= 0 then
      vim.notify("Failed to install lazy.nvim:\n" .. out, vim.log.levels.ERROR)
      return false
    end
    out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", LAZY_REVISION })
    if vim.v.shell_error ~= 0 then
      vim.notify("Failed to check out pinned lazy.nvim revision:\n" .. out, vim.log.levels.ERROR)
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
    lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
    install = {
      missing = not offline,
    },
    checker = {
      enabled = not offline,
      notify = false,
      frequency = 86400, -- Check for updates every day
    },
    change_detection = {
      enabled = not offline,
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
