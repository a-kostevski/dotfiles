return {
   {
      "nvim-telescope/telescope.nvim",
      cmd = "Telescope",
      event = "VimEnter",
      version = false,
      dependencies = {
         {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
            config = function(_)
               Utils.plugin.on_load("telescope.nvim", function()
                  require("telescope").load_extension("fzf")
               end)
            end,
         },
         "nvim-lua/plenary.nvim",
         { "nvim-telescope/telescope-ui-select.nvim" },
         { "nvim-tree/nvim-web-devicons" },
      },
      keys = {
         {
            "<leader>,",
            "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>",
            desc = "Switch Buffer",
         },
         { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Grep (Root Dir)" },
         { "<leader>:", "<cmd>Telescope command_history<cr>", desc = "Command History" },
         { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Find Files (Root Dir)" },
         -- find
         { "<leader>fb", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
         {
            "<leader>fc",
            function()
               require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
            end,
            desc = "Config",
         },
         {
            "<leader>ff",
            function()
               require("telescope.builtin").find_files({ cwd = Utils.root.get() })
            end,
            desc = "Find Files (Root Dir)",
         },
         {
            "<leader>fF",
            function()
               require("telescope.builtin").find_files({ root = false })
            end,
            desc = "Find Files (cwd)",
         },
         {
            "<leader>fg",
            function()
               require("telescope.builtin").live_grep({ cwd = Utils.root.get() })
            end,
            desc = "Live grep",
         },
         { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
         {
            "<leader>fR",
            function()
               require("telescope.builtin").oldfiles({ cwd = vim.uv.cwd() })
            end,
            desc = "Recent (cwd)",
         },
         -- git
         { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Commits" },
         { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Status" },
         -- search
         { '<leader>s"', "<cmd>Telescope registers<cr>", desc = "Registers" },
         { "<leader>sa", "<cmd>Telescope autocommands<cr>", desc = "Auto Commands" },
         { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Buffer" },
         { "<leader>sc", "<cmd>Telescope command_history<cr>", desc = "Command History" },
         { "<leader>sC", "<cmd>Telescope commands<cr>", desc = "Commands" },
         { "<leader>sd", "<cmd>Telescope diagnostics bufnr=0<cr>", desc = "Document Diagnostics" },
         { "<leader>sD", "<cmd>Telescope diagnostics<cr>", desc = "Workspace Diagnostics" },
         { "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "Grep (Root Dir)" },
         {
            "<leader>sG",
            function()
               require("telescope.builtin").live_grep({ root = false })
            end,
            desc = "Grep (cwd)",
         },
         { "<leader>sh", "<cmd>Telescope help_tags<cr>", desc = "Help Pages" },
         { "<leader>sH", "<cmd>Telescope highlights<cr>", desc = "Search Highlight Groups" },
         { "<leader>sj", "<cmd>Telescope jumplist<cr>", desc = "Jumplist" },
         { "<leader>sk", "<cmd>Telescope keymaps<cr>", desc = "Key Maps" },
         { "<leader>sl", "<cmd>Telescope loclist<cr>", desc = "Location List" },
         { "<leader>sM", "<cmd>Telescope man_pages<cr>", desc = "Man Pages" },
         { "<leader>sm", "<cmd>Telescope marks<cr>", desc = "Jump to Mark" },
         { "<leader>so", "<cmd>Telescope vim_options<cr>", desc = "Options" },
         { "<leader>sR", "<cmd>Telescope resume<cr>", desc = "Resume" },
         { "<leader>sq", "<cmd>Telescope quickfix<cr>", desc = "Quickfix List" },
         {
            "<leader>fu",
            "<cmd>Telescope colorscheme<cr>",
            { enable_preview = true, desc = "Colorscheme with Preview" },
         },
         -- { "<leader>sw", LazyVim.pick("grep_string", { word_match = "-w" }), desc = "Word (Root Dir)" },
         -- { "<leader>sW", LazyVim.pick("grep_string", { root = false, word_match = "-w" }), desc = "Word (cwd)" },
         -- { "<leader>sw", LazyVim.pick("grep_string"), mode = "v", desc = "Selection (Root Dir)" },
         -- { "<leader>sW", LazyVim.pick("grep_string", { root = false }), mode = "v", desc = "Selection (cwd)" },
         {
            "<leader>ss",
            function()
               require("telescope.builtin").lsp_document_symbols({
                  symbols = Utils.ui.get_kind_filter(),
               })
            end,
            desc = "Goto Symbol",
         },
         {
            "<leader>sS",
            function()
               require("telescope.builtin").lsp_dynamic_workspace_symbols({
                  symbols = Utils.ui.get_kind_filter(),
               })
            end,
            desc = "Goto Symbol (Workspace)",
         },
      },

      opts = function()
         local actions = require("telescope.actions")
         local open_with_trouble = function(...)
            return require("trouble.providers.telescope").open_with_trouble(...)
         end

         local find_files_no_ignore = function()
            local action_state = require("telescope.actions.state")
            local line = action_state.get_current_line()
            require("telescope.builtin").find_files({ no_ignore = true, default_text = line })()
         end

         local find_files_with_hidden = function()
            local action_state = require("telescope.actions.state")
            local line = action_state.get_current_line()
            require("telescope.builtin").find_files({ hidden = true, default_text = line })()
         end

         return {
            defaults = {
               -- Add trim option do defaults
               vimgrep_arguments = {
                  "rg",
                  "--color=never",
                  "--no-heading",
                  "--with-filename",
                  "--line-number",
                  "--column",
                  "--smart-case",
                  "--trim",
               },
               prompt_prefix = " ",
               selection_caret = " ",
               get_selection_window = function()
                  local wins = vim.api.nvim_list_wins()
                  table.insert(wins, 1, vim.api.nvim_get_current_win())
                  for _, win in ipairs(wins) do
                     local buf = vim.api.nvim_win_get_buf(win)
                     if vim.bo[buf].buftype == "" then
                        return win
                     end
                  end
                  return 0
               end,
               mappings = {
                  i = {
                     ["<c-t>"] = open_with_trouble,
                     ["<a-t>"] = open_with_trouble,
                     ["<a-i>"] = find_files_no_ignore,
                     ["<a-h>"] = find_files_with_hidden,
                     ["<C-Down>"] = actions.cycle_history_next,
                     ["<C-Up>"] = actions.cycle_history_prev,
                     ["<C-f>"] = actions.preview_scrolling_down,
                     ["<C-b>"] = actions.preview_scrolling_up,
                  },
                  n = {
                     ["q"] = actions.close,
                  },
               },
               preview = {
                  filesize_limit = 0.1, -- MB
               },
            },
            pickers = {
               find_files = {
                  find_command = { "rg", "--files", "--color=never", "--glob", "!**/.git/*", "-L" },
                  hidden = true,
                  mappings = {
                     n = {
                        ["cd"] = function(prompt_bufnr)
                           local selection = require("telescope.actions.state").get_selected_entry()
                           local dir = vim.fn.fnamemodify(selection.path, ":p:h")
                           require("telescope.actions").close(prompt_bufnr)
                           -- Depending on what you want put `cd`, `lcd`, `tcd`
                           vim.cmd(string.format("silent lcd %s", dir))
                        end,
                     },
                  },
               },
            },
            extensions = {
               ["ui-select"] = {
                  require("telescope.themes").get_dropdown(),
               },
               fzf = {},
            },
         }
      end,
   },
}
