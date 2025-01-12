return {
   "lewis6991/gitsigns.nvim",
   opts = {
      signs = {
         add = { text = "▎" },
         change = { text = "▎" },
         delete = { text = "" },
         topdelete = { text = "" },
         changedelete = { text = "▎" },
         untracked = { text = "▎" },
      },
      signs_staged = {
         add = { text = "▎" },
         change = { text = "▎" },
         delete = { text = "" },
         topdelete = { text = "" },
         changedelete = { text = "▎" },
      },
      on_attach = function(buf)
         local gs = package.loaded.gitsigns

         local wk = require("which-key")
         wk.add({
            {
               mode = { "n", "v" },
               group = "GHunk",
               {
                  "]h",
                  function()
                     if vim.wo.diff then
                        vim.cmd.normal({ cmd = "]c", bang = true })
                     else
                        gs.next_hunk()
                     end
                  end,
                  desc = "Next Hunk",
                  buffer = buf,
               },
               {
                  "[h",
                  function()
                     if vim.wo.diff then
                        vim.cmd.normal({ cmd = "[c", bang = true })
                     else
                        gs.prev_hunk()
                     end
                  end,
                  desc = "Prev Hunk",
                  buffer = buf,
               },
               {
                  "]H",
                  function()
                     gs.next_hunk()
                  end,
                  desc = "Next Hunk",
                  buffer = buf,
               },
               {
                  "[H",
                  function()
                     gs.prev_hunk()
                  end,
                  desc = "Prev Hunk",
                  buffer = buf,
               },
               {
                  "<leader>ghs",
                  ":Gitsigns stage_hunk<CR>",
                  desc = "Stage Hunk",
                  buffer = buf,
               },
               {
                  "<leader>ghS",
                  gs.stage_buffer,
                  desc = "Stage Buffer",
                  buffer = buf,
               },
               {
                  "<leader>ghr",
                  ":Gitsigns reset_hunk<CR>",
                  desc = "Reset Hunk",
                  buffer = buf,
               },
               {
                  "<leader>ghu",
                  gs.undo_stage_hunk,
                  desc = "Undo Stage Hunk",
                  buffer = buf,
               },
               {
                  "<leader>ghR",
                  gs.reset_buffer,
                  desc = "Reset Buffer",
                  buffer = buf,
               },
               {
                  "<leader>ghp",
                  gs.preview_hunk_inline,
                  desc = "Preview Hunk Inline",
                  buffer = buf,
               },
               {
                  "<leader>ghb",
                  function()
                     gs.blame_line({ full = true })
                  end,
                  desc = "Blame Line",
                  buffer = buf,
               },
               {
                  "<leader>ghB",
                  gs.toggle_current_line_blame,
                  desc = "Toggle Blame",
                  buffer = buf,
               },
               {
                  "<leader>ghd",
                  gs.diffthis,
                  desc = "Diff This",
                  buffer = buf,
               },
               {
                  "<leader>ghD",
                  function()
                     gs.diffthis("~")
                  end,
                  desc = "Diff This ~",
                  buffer = buf,
               },
               {
                  "ih",
                  ":<C-U>Gitsigns select_hunk<CR>",
                  desc = "GitSigns Select Hunk",
                  buffer = buf,
               },
            },
         })
      end,
   },
}
