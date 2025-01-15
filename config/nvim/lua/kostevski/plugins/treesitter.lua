return {
   {
      "nvim-treesitter/nvim-treesitter",
      version = false,
      event = { "BufReadPre", "BufNewFile" },
      cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
      build = ":TSUpdate",
      keys = {
         { "<c-space>", desc = "Increment Selection" },
         { "<bs>", desc = "Decrement Selection", mode = "x" },
      },
      opts_extend = { "ensure_installed" },
      opts = {
         sync_install = false,
         auto_install = true,
         ensure_installed = {
            "bash",
            "c",
            "gitignore",
            "html",
            "javascript",
            "json",
            "jsonc",
            "lua",
            "markdown",
            "markdown_inline",
            "printf",
            "python",
            "query",
            "regex",
            "toml",
            "vim",
            "vimdoc",
            "xml",
            "yaml",
         },
         indent = { enable = true },
         highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
         },
         incremental_selection = {
            enable = true,
            keymaps = {
               init_selection = "gnn",
               node_incremental = "grn",
               scope_incremental = "grc",
               node_decremental = "grm",
            },
            -- keymaps = {
            --    init_selection = "<C-space>",
            --    node_incremental = "<C-space>",
            --    scope_incremental = false,
            --    node_decremental = "<bs>",
            -- },
         },
         textobjects = {
            move = {
               enable = true,
               goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
               goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
               goto_previous_start = {
                  ["[f"] = "@function.outer",
                  ["[c"] = "@class.outer",
                  ["[a"] = "@parameter.inner",
               },
               goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
            },
         },
         playground = {
            enable = true,
         },
         refactor = {
            highlight_definitions = { enable = true },
            highlight_current_scope = { enable = false },
            smart_rename = {
               enable = true,
               keymaps = { smart_rename = "grr" },
            },
            navigation = {
               enable = true,
               keymaps = {
                  goto_definition_lsp_fallback = "gnd",
                  list_definitions = "gnD",
                  list_definitions_toc = "gO",
                  goto_next_usage = "<a-*>",
                  goto_previous_usage = "<a-#>",
               },
            },
         },
      },
      config = function(_, opts)
         require("nvim-treesitter.configs").setup(opts)
      end,
   },
   {
      "nvim-treesitter/nvim-treesitter-textobjects",
      event = "VeryLazy",
      enabled = true,
      config = function()
         Utils.toggle.create({
            name = "treesitter_context",
            get = function()
               return require("treesitter-context").enabled()
            end,
            set = function(_)
               local tsc = require("treesitter-context")
               tsc.toggle()
            end,
            keymap = "<leader>tc",
            desc = "Treesitter context",
         })

         if Utils.plugin.is_loaded("nvim-treesitter") then
            local opts = Utils.plugin.opts("nvim-treesitter")
            ---@diagnostic disable-next-line: missing-fields
            require("nvim-treesitter.configs").setup({ textobjects = opts.textobjects })
         end
         local move = require("nvim-treesitter.textobjects.move")
         local configs = require("nvim-treesitter.configs")
         for name, fn in pairs(move) do
            if name:find("goto") == 1 then
               move[name] = function(q, ...)
                  if vim.wo.diff then
                     local config = configs.get_module("textobjects.move")[name]
                     for key, query in pairs(config or {}) do
                        if q == query and key:find("[%]%[][cC]") then
                           vim.cmd("normal! " .. key)
                           return
                        end
                     end
                  end
                  return fn(q, ...)
               end
            end
         end
      end,
   },
   {
      "nvim-treesitter/nvim-treesitter-context",
      event = "VeryLazy",
      opts = {
         mode = "cursor",
         max_lines = 3,
         trim_scope = "outer",
         patterns = {
            default = {
               "class",
               "function",
               "method",
               "for",
               "while",
               "if",
               "switch",
               "case",
               "element",
               "call",
            },
         },
         zindex = 20,
      },
   },
   {
      "windwp/nvim-ts-autotag",
      opts = {},
   },
}
