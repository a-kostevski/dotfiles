return {
  {
    "saghen/blink.cmp",
    enabled = true,
    version = "*",
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
      "sources.completion.enabled_providers",
      "sources.default",
    },
    event = "InsertEnter",
    opts = {
      appearance = {
        nerd_font_variant = "mono",
        kind_icons = Utils.ui.icons.kinds,
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        trigger = {
          show_on_insert_on_trigger_character = true,
          show_on_keyword = true,
          show_on_trigger_character = true,
          show_on_accept_on_trigger_character = true,
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
          scrollbar = true,
          direction_priority = { "s", "n" },
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
                  local source, client = ctx.item.source_id, ctx.item.client_id

                  if client and vim.lsp.get_client_by_id(client).name then
                    source = vim.lsp.get_client_by_id(client).name
                  else
                    source = ctx.item.source_name
                  end
                  return "[ " .. source .. " ]"
                end,
              },
            },
          },
          winblend = vim.o.pumblend,
        },
      },
      sources = {
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
      fuzzy = {
        use_proximity = true,
        prebuilt_binaries = {
          download = true,
          force_version = nil,
        },
      },
    },
  },
}
