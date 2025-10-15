local lang = require("kostevski.utils.lang")

return lang.register({
  name = "html",
  filetypes = { "html", "htm", "xhtml" },
  root_markers = {
    "index.html",
    "package.json",
    ".git",
    "webpack.config.js",
    "vite.config.js",
    "gulpfile.js",
    "Gruntfile.js",
  },
  lsp_server = "html",
  formatters = {
    list = { "prettier", "htmlbeautifier" },
    tools = {
      "prettier",
      "htmlbeautifier",
    },
    config = {
      prettier = {
        extra_args = { "--parser", "html" },
      },
    },
  },
  linters = {
    list = { "htmlhint" },
    tools = { "htmlhint" },
  },
  treesitter_parsers = { "html" },
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
    softtabstop = 2,
  },
  additional_plugins = {
    {
      "mattn/emmet-vim",
      ft = { "html", "css", "javascript", "javascriptreact", "vue", "svelte" },
      config = function()
        vim.g.user_emmet_leader_key = "<C-Z>"
        vim.g.user_emmet_install_global = 0
        vim.g.user_emmet_settings = {
          html = {
            default_attributes = {
              option = { value = nil },
              textarea = { id = nil, name = nil, cols = 10, rows = 10 },
            },
            snippets = {
              ["!"] = "<!DOCTYPE html>\n"
                .. '<html lang="${lang}">\n'
                .. "<head>\n"
                .. '\t<meta charset="${charset}">\n'
                .. "\t<title></title>\n"
                .. '\t<meta name="viewport" content="width=device-width, initial-scale=1.0">\n'
                .. "</head>\n"
                .. "<body>\n\t${child}|\n</body>\n"
                .. "</html>",
            },
          },
        }
        vim.cmd("autocmd FileType html,css,javascript,javascriptreact,vue,svelte EmmetInstall")
      end,
    },
    {
      "windwp/nvim-ts-autotag",
      opts = {
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = false,
        },
        per_filetype = {
          ["html"] = {
            enable_close = true,
          },
        },
      },
    },
    {
      "NvChad/nvim-colorizer.lua",
      opts = {
        filetypes = { "html", "css", "javascript" },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          names = true,
          RRGGBBAA = false,
          AARRGGBB = false,
          rgb_fn = false,
          hsl_fn = false,
          css = false,
          css_fn = false,
          mode = "background",
          tailwind = false,
          sass = { enable = false, parsers = { "css" } },
          virtualtext = "■",
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
  },
})

