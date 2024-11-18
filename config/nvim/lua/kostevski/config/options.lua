vim.g.mapleader = " "
vim.g.localleader = "§"

-- Set default python interpreter to pyenv virtualenv shim named 'py3nvim'
vim.g.python3_host_prog = os.getenv("PYENV_ROOT") .. "/versions/py3nvim/bin/python"
vim.g.python_host_prog = os.getenv("PYENV_ROOT") .. "/versions/py3nvim/bin/python"

-- Perl interpreter

vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

local opt = vim.opt

-- Make line numbers default
opt.number = true

-- Enable mouse mode, can be useful for resizing splits for example!
opt.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
   opt.clipboard = "unnamedplus"
end)

-- Tabs to 2 spaces
opt.tabstop = 3
opt.softtabstop = 3
opt.shiftwidth = 3
opt.expandtab = true

-- Enable break indent
opt.breakindent = true

-- Save undo history
opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
opt.ignorecase = true
opt.smartcase = true

-- Keep signcolumn on by default
opt.signcolumn = "yes"

-- Decrease update time
opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
opt.timeoutlen = 300

-- Configure how new splits should be opened
opt.splitright = true
opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
opt.list = true
opt.listchars = {
   tab = "» ",
   trail = "·",
   nbsp = "␣",
}
opt.fillchars = {
   vert = "│",
   fold = " ",
}
-- Preview substitutions as you type
opt.inccommand = "split"

-- Show which line your cursor is on
opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
opt.scrolloff = 10

-- Insert visual separator att column width:
opt.colorcolumn = "120"

-- Disable swap- and backupfiles
opt.swapfile = true
opt.backup = false
opt.undofile = true

opt.relativenumber = true
opt.updatetime = 100
opt.foldlevel = 99
opt.formatexpr = "v:lua.Utils.format.formatexpr()"
opt.formatoptions = "jcroqlnt" -- tcqj
opt.smoothscroll = true
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.Utils.ui.foldexpr()"
opt.foldtext = ""

opt.syntax = "on"
