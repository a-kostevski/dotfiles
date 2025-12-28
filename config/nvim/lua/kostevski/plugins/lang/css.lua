local lang = require("kostevski.utils.lang")

return lang.register({
  name = "css",
  filetypes = { "css", "scss", "sass", "less", "stylus" },
  native_lsp = true, -- lsp/cssls.lua handles LSP config
  root_markers = {
    "package.json",
    "postcss.config.js",
    "tailwind.config.js",
    "tailwind.config.ts",
    "windi.config.js",
    "windi.config.ts",
    ".stylelintrc",
    ".stylelintrc.json",
    ".stylelintrc.js",
    "webpack.config.js",
    "vite.config.js",
    ".git",
  },
  lsp_server = "cssls",
  formatters = {
    list = { "prettier", "stylelint" },
    tools = {
      "prettier",
      "stylelint",
    },
    config = {
      prettier = {
        extra_args = { "--parser", "css" },
      },
    },
  },
  linters = {
    list = { "stylelint" },
    tools = { "stylelint" },
  },
  treesitter_parsers = { "css", "scss", "sass" },
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  additional_plugins = {
    {
      "NvChad/nvim-colorizer.lua",
      opts = {
        filetypes = { "css", "scss", "sass", "less", "stylus", "html", "javascript" },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          names = true,
          RRGGBBAA = true,
          AARRGGBB = false,
          rgb_fn = true,
          hsl_fn = true,
          css = true,
          css_fn = true,
          mode = "background",
          tailwind = "lsp",
          sass = { enable = true, parsers = { "css" } },
          virtualtext = "■",
          always_update = false,
        },
        buftypes = {},
      },
    },
    {
      "roobert/tailwindcss-colorizer-cmp.nvim",
      config = function()
        require("tailwindcss-colorizer-cmp").setup({
          color_square_width = 2,
        })
      end,
    },
    {
      "mattn/emmet-vim",
      ft = { "html", "css", "scss", "sass", "less", "stylus" },
      config = function()
        vim.g.user_emmet_leader_key = "<C-Z>"
        vim.g.user_emmet_install_global = 0
        vim.cmd("autocmd FileType css,scss,sass,less,stylus EmmetInstall")
      end,
    },
    {
      "luckasRanarison/tailwind-tools.nvim",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      opts = {
        server = {
          override = false, -- Don't use lspconfig, use native vim.lsp.config
        },
        document_color = {
          enabled = true,
          kind = "inline",
          inline_symbol = "󰝤 ",
          debounce = 200,
        },
        conceal = {
          enabled = false,
          symbol = "󱏿",
          highlight = {
            fg = "#38BDF8",
          },
        },
        custom_filetypes = {},
      },
    },
    {
      "razak17/tailwind-fold.nvim",
      opts = {},
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      ft = { "html", "svelte", "astro", "vue", "typescriptreact", "php", "blade" },
    },
  },
})

