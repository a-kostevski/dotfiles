return {
   {
      "nvim-treesitter/nvim-treesitter",
      version = false, -- last release is way too old
      build = ":TSUpdate",
      event = { "VeryLazy" },
      init = function(plugin)
         -- PERF: add nvim-treesitter queries to rtp and it's custom query predicates
         require("lazy.core.loader").add_to_rtp(plugin)
         require("nvim-treesitter.query_predicates")
      end,
      dependencies = {
         {
            "nvim-treesitter/nvim-treesitter-textobjects",
            config = function()
               -- When in diff mode, we want to use the default
               -- vim text objects c & C instead of the treesitter ones.
               local move = require("nvim-treesitter.textobjects.move") ---@type table<string,fun(...)>
               local configs = require("nvim-treesitter.configs")
               for name, fn in pairs(move) do
                  if name:find("goto") == 1 then
                     move[name] = function(...)
                        if vim.wo.diff then
                           return require("diffview.config").diffview_callback()
                        end
                        return fn(...)
                     end
                  end
               end
            end,
         },
      },
      cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
      keys = {
         { "<c-space>", desc = "Increment selection" },
         { "<bs>", desc = "Decrement selection", mode = "x" },
      },
      opts = {
            auto_install = true,
         highlight = { enable = true },
         indent = { enable = true },
         ensure_installed = {
            "bash",
            "c",
            "diff",
            "html",
            "javascript",
            "jsdoc",
            "lua",
            "luadoc",
            "luap",
            "query",
            "regex",
            "toml",
            "tsx",
            "typescript",
            "vim",
            "vimdoc",
            "yaml",
         },
         incremental_selection = {
            enable = true,
            keymaps = {
               init_selection = "<C-space>",
               node_incremental = "<C-space>",
               scope_incremental = false,
               node_decremental = "<bs>",
            },
         },
         textobjects = {
            move = {
               enable = true,
               goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
               goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
               goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
               goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
            },
         },
      },
      config = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            local added = {}
            opts.ensure_installed = vim.tbl_filter(function(parser)
               if added[parser] then
                  return false
               end
               added[parser] = true
               return true
            end, opts.ensure_installed)
         end
         require("nvim-treesitter.configs").setup(opts)
      end,
   },
}
