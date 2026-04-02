vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Disable unused providers
vim.g.python3_host_prog = (vim.env.HOME or "") .. "/.local/share/uv/venv/py3nvim/bin/python"
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
vim.schedule(function()
   opt.clipboard = "unnamedplus"
end)

-- Tabs to 2 spaces
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true

opt.breakindent = true
opt.undofile = true
opt.swapfile = true
opt.backup = false

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
opt.ignorecase = true
opt.smartcase = true

opt.signcolumn = "yes"
opt.updatetime = 100
opt.timeoutlen = 300

-- Splits
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"

opt.fillchars = {
   vert = "│",
   fold = " ",
}

opt.inccommand = "split"
opt.cursorline = true
opt.scrolloff = 10
opt.smoothscroll = true
opt.colorcolumn = "120"

-- Folding
opt.foldlevel = 99
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""
