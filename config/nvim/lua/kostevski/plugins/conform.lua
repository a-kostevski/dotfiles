return {
   {
      "stevearc/conform.nvim",
      event = { "BufReadPre", "BufNewFile" },
      cmd = { "ConformInfo" },
      init = function()
         vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
         Utils.format.register({
            name = "conform.nvim",
            priority = 100,
            primary = true,
            format = function(buf)
               require("conform").format({ bufnr = buf })
            end,
            sources = function(buf)
               local ret = require("conform").list_formatters(buf)
               return vim.tbl_map(function(v)
                  return v.name
               end, ret)
            end,
         })
      end,
      opts = {
         default_format_opts = {
            timeout_ms = 3000,
            async = false,
            quiet = false,
            lsp_format = "fallback",
         },
         formatters_by_ft = {
            lua = { "stylua" },
            python = { "isort", "black" },
            markdown = { "prettierd" },
            sh = { "shfmt" },
            zsh = { "shfmt" },
            rust = { "rustfmt", lsp_format = "fallback" },
         },
         formatters = {
            injected = {
               ignore_errors = true,
            },
            shfmt = {
               prepend_args = { "-i", "2" },
            },
         },
      },

      config = function(_, opts)
         require("conform").setup(opts)
      end,
   },
   {
      "williamboman/mason.nvim",
      opts = {
         ensure_installed = {
            "isort",
            "black",
            "stylua",
            "selene",
            "prettierd",
            "shfmt",
         },
      },
   },
}
