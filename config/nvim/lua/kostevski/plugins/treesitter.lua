return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
      -- provides the `textobjects` query group mini.ai reads for @function/
      -- @class/@block; main branch to match nvim-treesitter's main branch
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
      {
        "OXY2DEV/markview.nvim",
        enabled = function()
          return require("kostevski.utils.lang").is_enabled("markdown")
        end,
      },
    },
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "diff",
        "html",
        "ini",
        "javascript",
        "json",
        "json5",
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
      local parsers = Utils.dedup(opts.ensure_installed or {})

      local ts = require("nvim-treesitter")
      ts.install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("kostevski_treesitter", { clear = true }),
        callback = function(args)
          local ft = args.match
          local lang = vim.treesitter.language.get_lang(ft) or ft
          if pcall(vim.treesitter.language.inspect, lang) then
            vim.treesitter.start(args.buf)
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
