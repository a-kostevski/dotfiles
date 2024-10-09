local map = vim.keymap

-- [[ Basic Keymaps ]]
--  See `:help map.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
map.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
-- map.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })


-- Exit terminal mode in the ts terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
map.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
map.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
map.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
map.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
map.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
map.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
map.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
map.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
map.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

map.set('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New file' })

-- Save file
map.set({ "i", "x", "n", "s" }, '<leader>w', '<cmd>w<cr><esc>', { desc = '[W]rite' })
map.set('n', '<leader>q', '<cmd>confirm q<cr>', { desc = 'Quit window' })
map.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })
map.set('n', '<leader>Q', '<cmd>confirm qall<cr>', { desc = 'Quit nvim' })
map.set('n', '<leader>c', '<cmd>lua MiniBufremove.delete()<cr>', { desc = '[C]lose buffer' })

map.set('n', '<leader>bn', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map.set('n', '<leader>bp', '<cmd>bprev<cr>', { desc = 'Previous buffer' })
vim.keymap.set('x', '<leader>p', [["_dP]])

-- tabs
map.set('n', '<leader><tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
map.set('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
map.set('n', '<leader><tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
map.set('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
map.set('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
map.set('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
map.set('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })


map.set('n', '<leader>rr', '<cmd>source $MYVIMRC<cr>', { desc = 'Reload nvim' })
