vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Disable python providers
vim.g.python3_host_prog = nil
vim.g.python_host_prog = nil

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
vim.schedule(function()
   opt.clipboard = "unnamedplus"
end)

-- Tabs to 2 spaces
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
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
opt.smoothscroll = true

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
opt.formatoptions = "jcroqlnt"
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.Utils.ui.foldexpr()"
opt.foldtext = ""

opt.termguicolors = true
opt.syntax = "on"

-- Add these performance-related options
opt.lazyredraw = true
opt.redrawtime = 1500
opt.timeoutlen = 300
opt.updatetime = 250
opt.maxmempattern = 2000

-- Better split handling
opt.splitkeep = "screen"
opt.splitright = true
opt.splitbelow = true
