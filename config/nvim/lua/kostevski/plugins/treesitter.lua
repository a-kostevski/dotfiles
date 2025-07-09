return {
   {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      branch = "main",
      build = ":TSUpdate",
      dependencies = {
         {
            "OXY2DEV/markview.nvim",
         },
      },
      opts = {
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
      },
      config = function(_, opts)
         -- Remove duplicate parsers from ensure_installed
         opts.ensure_installed = Utils.dedup(opts.ensure_installed)

         -- Setup nvim-treesitter
         require("nvim-treesitter").setup(opts)

         -- Auto-install configured parsers
         if opts.auto_install ~= false and opts.ensure_installed then
            local parsers_to_install = {}
            local installed = require("nvim-treesitter").get_installed()

            for _, parser in ipairs(opts.ensure_installed) do
               if not vim.tbl_contains(installed, parser) then
                  table.insert(parsers_to_install, parser)
               end
            end

            if #parsers_to_install > 0 then
               require("nvim-treesitter").install(parsers_to_install)
            end
         end

         -- Enable highlighting for all buffers with treesitter parsers
         vim.api.nvim_create_autocmd("FileType", {
            callback = function(event)
               local lang = vim.treesitter.language.get_lang(event.match)
               if lang and pcall(vim.treesitter.get_parser, event.buf, lang) then
                  vim.treesitter.start(event.buf, lang)
               end
            end,
         })

         -- Enable treesitter-based folding
         vim.api.nvim_create_autocmd("FileType", {
            callback = function(event)
               local lang = vim.treesitter.language.get_lang(event.match)
               if lang and pcall(vim.treesitter.get_parser, event.buf, lang) then
                  vim.wo.foldmethod = "expr"
                  vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
               end
            end,
         })

         -- Enable treesitter indentation for specific filetypes
         local indent_filetypes = { "lua", "python", "rust", "javascript", "typescript", "tsx", "jsx" }
         vim.api.nvim_create_autocmd("FileType", {
            pattern = indent_filetypes,
            callback = function(event)
               local lang = vim.treesitter.language.get_lang(event.match)
               if lang then
                  vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
               end
            end,
         })
      end,
   },
}
