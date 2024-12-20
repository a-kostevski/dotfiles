return {
   {
      "stevearc/conform.nvim",
      optional = true,
      opts = {
         formatters_by_ft = {
            ["markdown"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
            ["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
         },
      },
   },
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
            "<leader>um",
            "<cmd>MarkdownPreviewToggle<cr>",
            ft = "markdown",
            desc = "Markdown Preview",
         },
      },
   },
   {
      "OXY2DEV/markview.nvim",
      dependencies = {
         "nvim-treesitter/nvim-treesitter",
         "nvim-tree/nvim-web-devicons",
      },
      opts = {
         block_quotes = {
            default = {
               border = "▋",
               hl = "NONE",
            },
            enable = true,
         },
         buf_ignore = { "nofile", "copilot-chat", "copilot-*" },
         checkboxes = {
            enable = true,
            -- checked = { text = "✔" },
            -- custom = {
            --    {
            --       match_string = "-",
            --       icon = "◯",
            --       hl = "CheckboxPending",
            --    },
            -- },
         },
         code_blocks = {
            enable = true,
            -- hl = "NONE",
            -- info_hl = "NONE",
            language_direction = "left",
            language_names = {
               ["txt"] = "Text",
            },
            min_width = 60,
            pad_amount = 2,
            pad_char = " ",
            sign = true,
            sign_hl = nil,
            style = "language",
         },
         headings = {
            enable = true,
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
         inline_codes = {
            corner_left = nil,
            corner_right = nil,
            enable = true,
            hl = "MarkviewInlineCode",
            padding_left = nil,
            padding_right = nil,
         },
         links = {
            emails = {
               enable = true,
               hl = "MarkviewLink",
               icon = nil,
            },
            enable = true,
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
         },
      },
      list_items = {
         indent_size = 1,
         shift_width = 2,
      },
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
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
            "marksman",
            "markdownlint-cli2",
            "markdown-toc",
         })
      end,
   },
   {
      "mfussenegger/nvim-lint",
      optional = true,
      opts = function(_, opts)
         opts.linters_by_ft = opts.linters_by_ft or {}
         vim.tbl_extend("force", opts.linters_by_ft, {
            markdown = { "markdownlint-cli2" },
         })
      end,
   },
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            marksman = {},
         },
      },
   },
}
