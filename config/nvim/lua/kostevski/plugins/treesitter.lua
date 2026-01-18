return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
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

      -- Enable built-in modules
      opts.highlight = { enable = true }
      opts.indent = { enable = true }

      -- Setup nvim-treesitter (handles ensure_installed automatically)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
