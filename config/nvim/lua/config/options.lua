local opt = vim.opt

vim.g.mapleader = ' '
vim.g.localleader = ','

-- Set default python interpreter to pyenv virtualenv shim named 'py3nvim'
vim.g.python3_host_prog = os.getenv("PYENV_ROOT") .. '/versions/py3nvim/bin/python'
vim.g.python_host_prog = os.getenv("PYENV_ROOT") .. '/versions/py3nvim/bin/python'

-- Make line numbers default
opt.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
opt.mouse = 'a'

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
	opt.clipboard = 'unnamedplus'
end)

-- Tabs to 4 spaces
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- Enable break indent
opt.breakindent = true

-- Save undo history
opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
opt.ignorecase = true
opt.smartcase = true

-- Keep signcolumn on by default
opt.signcolumn = 'yes'

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
	tab = '» ',
	trail = '·',
	nbsp = '␣'
}

-- Preview substitutions as you type
opt.inccommand = 'split'

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
