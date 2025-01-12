local icons = Utils.ui.icons

return {
   "nvim-neo-tree/neo-tree.nvim",
   cmd = "Neotree",
   enabled = true,
   dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
   },
   init = function()
      if not Utils.plugin.is_loaded("neo-tree") then
         vim.api.nvim_create_autocmd("BufEnter", {
            group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
            desc = "Load Neotree if entering a directory",
            once = true,
            callback = function()
               if package.loaded["neo-tree"] then
                  return
               else
                  local stats = vim.uv.fs_stat(vim.fn.argv(0))
                  if stats and stats.type == "directory" then
                     require("neo-tree")
                  end
               end
            end,
         })
      end
   end,
   deactivate = function()
      vim.cmd([[Neotree close]])
   end,
   keys = {
      {
         "<leader>e",
         function()
            require("neo-tree.command").execute({ toggle = true, dir = Utils.root.get() })
         end,
         desc = "Explorer Neotree (Root Dir)",
      },
      {
         "<leader>E",
         function()
            require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
         end,
         desc = "Explorer Neotree (cwd)",
      },
      {
         "<leader>ge",
         function()
            require("neo-tree.command").execute({ source = "git_status", toggle = true })
         end,
         desc = "Git Explorer",
      },
      {
         "<leader>be",
         function()
            require("neo-tree.command").execute({ source = "buffers", toggle = true })
         end,
         desc = "Buffer Explorer",
      },
   },

   opts = {
      hide_root_node = true,
      enable_git_status = true,
      git_status_async = true,
      commands = {

         trash = function(state)
            local path = state.tree:get_node():get_id()
            local trash_cmd = vim.fn.has("mac") == 1 and { "trash", path } or { "gio", "trash", path }

            local result = vim.fn.system(trash_cmd)
            if vim.v.shell_error ~= 0 then
               vim.notify("Failed to move file to trash: " .. result, vim.log.levels.ERROR)
               return
            end
            require("neo-tree.sources.manager").refresh()
         end,

         -- Open file in system
         system_open = function(state)
            local path = state.tree:get_node():get_id()
            local cmd = vim.fn.has("mac") == 1 and "open" or "xdg-open"

            local job = vim.fn.jobstart({ cmd, path }, {
               detach = true,
               on_stderr = function(_, data)
                  if data then
                     vim.notify("Error opening file: " .. vim.fn.join(data, ""), vim.log.levels.ERROR)
                  end
               end,
            })
            if job <= 0 then
               vim.notify("Failed to open file", vim.log.levels.ERROR)
            end
         end,

         -- Yank path
         yank_path = function(state)
            local node = state.tree:get_node()
            local path = node and node:get_id()
            if path then
               vim.fn.setreg("+", path, "c")
               vim.notify("Path copied to clipboard", vim.log.levels.INFO)
            end
         end,
      },

      event_handlers = {
         -- Close when opening file
         {
            event = "file_open_requested",
            handler = function()
               vim.cmd([[Neotree close]])
            end,
         },
         {
            event = "neo_tree_window_after_open",
            handler = function(args)
               if args.position == "left" or args.position == "right" then
                  vim.cmd("wincmd =")
               end
            end,
         },
         {
            event = "neo_tree_window_after_close",
            handler = function(args)
               if args.position == "left" or args.position == "right" then
                  vim.cmd("wincmd =")
               end
            end,
         },
         {
            event = "neo_tree_buffer_enter",
            handler = function()
               vim.cmd("highlight! Cursor blend=100")
            end,
         },
         {
            event = "neo_tree_buffer_leave",
            handler = function()
               vim.cmd("highlight! Cursor guibg=#5f87af blend=0")
            end,
         },
      },

      -- sync_root_with_cwd = false,
      -- respect_buf_cwd = true,

      update_focused_file = {
         enable = true,
         update_root = true,
      },

      filesystem = {
         bind_to_cwd = false,
         follow_current_file = { enabled = true },
         use_libuv_file_watcher = true,
         filtered_items = {
            visible = true,
            hide_hidden = false,
            hide_dotfiles = false,
            never_show = {
               ".DS_Store",
            },
         },
         window = {
            mappings = {
               ["o"] = "system_open",
            },
         },
      },
      default_component_configs = {
         indent = {
            with_expanders = true,
            expander_collapsed = "",
            expander_expanded = "",
            expander_highlight = "NeotreeExpander",
         },
         git_status = {
            symbols = {
               added = icons.git.add,
               deleted = icons.git.removed,
               renamed = icons.git.renamed,
               untracked = icons.git.untracked or "",
               ignored = icons.git.ignored or "",
               unstaged = icons.git.unstaged,
               staged = icons.git.staged or "",
               conflict = icons.git.conflict or "",
            },
         },
      },
      sources = { "filesystem", "buffers", "git_status" },
      source_selector = {
         winbar = true,
         statusline = false,
      },
      open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },
      window = {
         position = "left",
         width = 45,
         mappings = {
            ["e"] = {
               function()
                  vim.cmd("Neotree focus filesystem left")
               end,
               desc = "filesystem",
            },
            ["b"] = {
               function()
                  vim.cmd("Neotree focus buffers left")
               end,
               desc = "buffers",
            },
            ["d"] = "trash",
            ["g"] = {
               function()
                  vim.cmd("Neotree focus git_status left")
               end,
               desc = "git status",
            },
            ["l"] = "open",
            ["h"] = "close_node",
            ["<space>"] = "none",
            ["Y"] = "yank_path",
            ["p"] = { "toggle_preview", config = { use_float = true } },
         },
      },
   },
   config = function(_, opts)
      local function on_move(data)
         local ok, err = pcall(Utils.lsp.on_rename, data.source, data.destination)
         if not ok then
            vim.notify("Failed to notify LSP of file rename: " .. err, vim.log.levels.WARN)
         end
      end

      local events = require("neo-tree.events")
      opts.event_handlers = opts.event_handlers or {}
      vim.list_extend(opts.event_handlers, {
         { event = events.FILE_MOVED, handler = on_move },
         { event = events.FILE_RENAMED, handler = on_move },
      })
      require("neo-tree").setup(opts)
   end,
}
