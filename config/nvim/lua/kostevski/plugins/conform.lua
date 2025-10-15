return {
  {
    "stevearc/conform.nvim",
  dependencies = { "mason.nvim" },
  lazy = true,
  cmd = "ConformInfo",
    event = { "BufReadPre", "BufNewFile" },
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
    opts = function()
      local opts = {
        default_format_opts = {
          timeout_ms = 3000,
          async = false,
          quiet = false,
          lsp_format = "fallback",
        },
        formatters_by_ft = {
          bash = { "shfmt" },
          css = { "prettierd" },
          lua = { "stylua" },
          html = { "prettierd" },
          javascript = { "prettierd" },
          markdown = { "prettierd" },
          sh = { "shfmt" },
        },
        formatters = {
          injected = {
            ignore_errors = false,
            lang_to_ext = {
              bash = "sh",
              latex = "tex",
              lua = "lua",
              markdown = "md",
              python = "py",
              javascript = "js",
              rust = "rs",
            },
          },
          shfmt = {
            prepend_args = { "-i", "2", "-ci" },
          },
        },
      }
      return opts
    end,

    config = function(_, opts)
      Utils.debug.dump({ formatters_by_ft = opts.formatters_by_ft, formatters = vim.tbl_keys(opts.formatters) })
      require("conform").setup(opts)
    end,
  },
}
