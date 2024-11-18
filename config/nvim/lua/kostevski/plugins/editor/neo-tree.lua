return {
   "nvim-neo-tree/neo-tree.nvim",
   cmd = "Neotree",
   dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
   },
   keys = {
      {
         "<leader>fe",
         function()
            require("neo-tree.command").execute({ toggle = true, dir = Utils.root.get() })
         end,
         desc = "Explorer NeoTree (Root Dir)",
      },
      {
         "<leader>fE",
         function()
            require("neo-tree.command").execute({ toggle = true, dir = vim.uv.cwd() })
         end,
         desc = "Explorer NeoTree (cwd)",
      },
      { "<leader>e", "<leader>fe", desc = "Explorer NeoTree (Root Dir)", remap = true },
      { "<leader>E", "<leader>fE", desc = "Explorer NeoTree (cwd)", remap = true },
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
      commands = {
         grug_far_replace = function(state)
            local node = state.tree:get_node()
            local prefills = {
               paths = node.type == "directory" and node:get_id() or vim.fn.fnamemodify(node:get_id(), ":h"),
            }

            local grug_far = require("grug-far")
            if not grug_far.has_instance("explorer") then
               grug_far.open({
                  instanceName = "explorer",
                  prefills = prefills,
                  staticTitle = "Find and Replace from Explorer",
               })
            else
               grug_far.open_instance("explorer")
               grug_far.update_instance_prefills("explorer", prefills, false)
            end
         end,

         -- Open file in system
         system_open = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.jobstart({ "open", path }, { detach = true })
            vim.cmd("silent !start explorer " .. p)
         end,

         -- Yank path
         yank_path = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.setreg("+", path, "c")
         end,
      },

      event_handlers = {
         -- Close when opening file
         {
            event = "file_open_requested",
            handler = function()
               vim.cmd("Neotree close")
               -- require("neo-tree.command").execute({ action = "close" })
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

         -- Hide cursor when opening Neotree
         {
            event = "neo_tree_buffer_enter",
            handler = function()
               vim.cmd("highlight! Cursor blend=100")
            end,
         },
         -- Restore cursor visibility
         {
            event = "neo_tree_buffer_leave",
            handler = function()
               vim.cmd("highlight! Cursor guibg=#5f87af blend=0")
            end,
         },
      },

      sources = { "filesystem", "buffers", "git_status" },
      sync_root_with_cwd = true,
      respect_buf_cwd = true,

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
               ["R"] = "grug_far_replace",
            },
         },
      },
      default_component_configs = {
         indent = {
            with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
            expander_collapsed = "",
            expander_expanded = "",
            expander_highlight = "NeoTreeExpander",
         },
         git_status = {
            symbols = {
               unstaged = "󰄱",
               staged = "󰱒",
            },
         },
      },
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
                  vim.cmd("Neotree focus filesystem left", true)
               end,
               desc = "filesystem",
            },
            ["b"] = {
               function()
                  vim.cmd("Neotree focus buffers left", true)
               end,
               desc = "buffers",
            },
            ["g"] = {
               function()
                  vim.cmd("Neotree focus git_status left", true)
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
         Utils.lsp.on_rename(data.source, data.destination)
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
