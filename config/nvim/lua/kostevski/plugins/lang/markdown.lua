local lang = require("kostevski.utils.lang")

return lang.register({
  name = "markdown",
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = {
    -- Documentation projects
    "index.md",
    "docs/",
    "documentation/",
    -- Static site generators
    "_config.yml", -- Jekyll
    "config.toml", -- Hugo
    "config.yaml",
    "mkdocs.yml", -- MkDocs
    "book.toml", -- mdBook
    ".vuepress/", -- VuePress
    ".vitepress/", -- VitePress
    "gatsby-config.js", -- Gatsby
    "next.config.js", -- Next.js
    "nuxt.config.js", -- Nuxt
    "docusaurus.config.js", -- Docusaurus
    ".docsify/", -- Docsify
    "_sidebar.md", -- Docsify
    -- Wiki
    "wiki/",
    ".wiki/",
    "_wiki/",
    -- Notebook
    "notebook/",
    "notes/",
    -- Blog
    "_posts/",
    "posts/",
    "blog/",
    "content/",
    -- Book/Manual
    "SUMMARY.md", -- GitBook/mdBook
    "manuscript/",
    "chapters/",
    ".git",
  },
  lsp_server = "marksman",
  formatters = {
    list = { "prettier", "markdownlint-cli2", "markdown-toc" },
    tools = { "markdownlint-cli2", "markdown-toc", "prettierd" },
    config = {
      ["markdown-toc"] = {
        condition = function(_, ctx)
          for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
            if line:find("<!%-%- toc %-%->") then
              return true
            end
          end
        end,
      },
      ["markdownlint-cli2"] = {
        condition = function(_, ctx)
          local diag = vim.tbl_filter(function(d)
            return d.source == "markdownlint"
          end, vim.diagnostic.get(ctx.buf))
          return #diag > 0
        end,
      },
    },
  },
  linters = {
    list = { "markdownlint-cli2" },
    tools = { "markdownlint-cli2" },
  },
  treesitter_parsers = { "markdown", "markdown_inline" },
  additional_plugins = {
    -- Markdown Preview
    {
      "iamcco/markdown-preview.nvim",
      build = function()
        vim.fn["mkdp#util#install"]()
      end,
      cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
      config = function()
        vim.g.mkdp_filetypes = { "markdown" }
      end,
      ft = { "markdown" },
      keys = {
        {
          "<leader>tm",
          "<cmd>MarkdownPreviewToggle<cr>",
          ft = "markdown",
          desc = "Markdown Preview",
        },
      },
    },
    -- Markdown render
    {
      "OXY2DEV/markview.nvim",
      lazy = false,
      priority = 49,
      dependencies = {
        "nvim-tree/nvim-web-devicons",
      },
      opts = function()
        return {
          markdown = {
            block_quotes = {
              default = {
                border = "▋",
                hl = "NONE",
              },
              enable = true,
            },
            code_blocks = {
              enable = true,
              min_width = 60,
              pad_amount = 2,
              pad_char = " ",
              sign = true,
              sign_hl = nil,
              style = "language",
            },
            checkboxes = {
              enable = true,
              custom = {
                {
                  match_string = "-",
                  icon = "◯",
                  hl = "CheckboxPending",
                },
              },
            },
            headings = {
              shift_width = 1,
              heading_1 = {
                hl = "MarkviewHeading1",
                icon = "",
              },
              heading_2 = {
                hl = "MarkviewHeading2",
                icon = "",
              },
              heading_3 = {
                hl = "MarkviewHeading3",
                icon = "",
              },
              heading_4 = {
                hl = "MarkviewHeading4",
                icon = "",
              },
              heading_5 = {
                hl = "MarkviewHeading5",
                icon = "",
              },
              heading_6 = {
                hl = "MarkviewHeading6",
                icon = "",
              },
            },
            list_items = {
              indent_size = 1,
              shift_width = 1,
              marker_minus = {
                text = "•",
              },
              marker_plus = {
                text = "·",
              },
            },
          },
          markdown_inline = {
            emails = {
              enable = true,
              hl = "MarkviewLink",
              icon = nil,
            },
            hyperlinks = {
              enable = true,
              hl = "MarkviewLink",
              icon = nil,
            },
            images = {
              enable = true,
              hl = "MarkviewLink",
              icon = nil,
            },
            inline_codes = {
              corner_left = nil,
              corner_right = nil,
              enable = true,
              hl = "MarkviewInlineCode",
              padding_left = nil,
              padding_right = nil,
            },
          },
          preview = {
            ignore_buftypes = { "nofile", "copilot-chat", "copilot-*" },
          },
        }
      end,
      config = function(_, opts)
        local colors = {
          heading1 = "#E06C75", -- Soft red
          heading2 = "#61AFEF", -- Sky blue
          heading3 = "#98C379", -- Sage green
          heading4 = "#C678DD", -- Muted purple
          heading5 = "#E5C07B", -- Warm yellow
          heading6 = "#56B6C2", -- Teal
        }
        -- Setup highlight groups
        vim.api.nvim_set_hl(0, "MarkviewHeading1", { fg = colors.heading1, bold = true })
        vim.api.nvim_set_hl(0, "MarkviewHeading2", { fg = colors.heading2, bold = true })
        vim.api.nvim_set_hl(0, "MarkviewHeading3", { fg = colors.heading3, bold = true })
        vim.api.nvim_set_hl(0, "MarkviewHeading4", { fg = colors.heading4 })
        vim.api.nvim_set_hl(0, "MarkviewHeading5", { fg = colors.heading5 })
        vim.api.nvim_set_hl(0, "MarkviewHeading6", { fg = colors.heading6 })

        vim.api.nvim_set_hl(0, "MarkviewInlineCode", { fg = colors.heading6 })
        vim.api.nvim_set_hl(0, "MarkviewLink", { fg = colors.heading6, underline = true })
        require("markview").setup(opts)
      end,
    },
  },
})
