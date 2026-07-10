return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = {
      {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = "make install_jsregexp",
        dependencies = {
          {
            "rafamadriz/friendly-snippets",
            config = function()
              require("luasnip").filetype_extend("markdown_inline", { "markdown" })
              require("luasnip.loaders.from_lua").lazy_load({
                paths = { vim.fn.stdpath("config") .. "/snippets" },
              })
              require("luasnip.loaders.from_vscode").lazy_load()
            end,
          },
        },
        opts = { history = true, delete_check_events = "TextChanged" },
      },
      { "rafamadriz/friendly-snippets" },
    },
    opts_extend = {
      "sources.default",
    },
    -- blink actually loads earlier than these events in practice: nvim-lspconfig's
    -- `config` fn (event = { "BufReadPre", "BufNewFile" }, see plugins/lsp/lspconfig.lua)
    -- synchronously calls Utils.lsp.capabilities.get_default_capabilities(), which
    -- pcall-requires "blink.cmp" to merge in its LSP capabilities -- that require is
    -- what actually triggers lazy.nvim to load the plugin for any real file. These
    -- events remain as a fallback so blink still loads for buffers with no LSP client
    -- (InsertEnter) and for cmdline completion used before any buffer is opened
    -- (CmdlineEnter).
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      appearance = {
        kind_icons = Utils.ui.icons.kinds,
      },
      completion = {
        trigger = {
          show_on_x_blocked_trigger_characters = { "'", '"', "(" },
        },
        ghost_text = {
          enabled = true,
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 100,
          window = {
            border = "single",
          },
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          border = "single",
          min_width = 25,
          max_height = 30,
          draw = {
            columns = { { "label", "label_description", gap = 1 }, { "kind" } },
            components = {
              kind_icon = {
                text = function(ctx)
                  return Utils.ui.icons.kinds[ctx.kind]
                end,
              },
              kind = {
                text = function(ctx)
                  return "[ " .. ctx.kind_icon .. ctx.icon_gap .. ctx.kind .. " ]"
                end,
                width = {
                  fill = true,
                  max = 25,
                },
              },
              label = {
                text = function(ctx)
                  return ctx.item.label
                end,
                width = {
                  max = 35,
                },
              },
              label_description = {
                text = function(ctx)
                  return ctx.item.label_description
                end,
              },
              source_name = {
                text = function(ctx)
                  local client = ctx.item.client_id and vim.lsp.get_client_by_id(ctx.item.client_id)
                  local source = (client and client.name) or ctx.item.source_name
                  return "[ " .. source .. " ]"
                end,
              },
            },
          },
          winblend = vim.o.pumblend,
        },
      },
      sources = {
        -- Kept even though it matches blink's own built-in default: lazydev.lua's
        -- blink spec fragment sets sources.default = { "lazydev" }, and this key is
        -- in opts_extend, so lazy.nvim concatenates the two fragments' lists. Without
        -- a base list here, lazydev's fragment would be the *only* one contributing
        -- to the merged sources.default, dropping lsp/path/snippets/buffer.
        default = { "lsp", "path", "snippets", "buffer" },
        min_keyword_length = 1,
      },
      cmdline = {
        sources = { "path", "buffer", "cmdline" },
      },
      snippets = {
        preset = "luasnip",
      },
      keymap = {
        preset = "enter",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      signature = {
        enabled = true,
        window = {
          border = "single",
        },
      },
    },
  },
}
