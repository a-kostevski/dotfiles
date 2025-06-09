return {
   {
      "saghen/blink.cmp",
      enabled = true,
      version = "0.10.0",
      dependencies = {
         { "rafamadriz/friendly-snippets" },
         { "L3MON4D3/LuaSnip", version = "2.*" },
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
            default = { "snippets", "lsp", "path", "buffer" },
            cmdline = {},
            min_keyword_length = 2,
         },
         snippets = {
            preset = "luasnip",
         },
         keymap = {
            preset = "enter",
            ["<Tab>"] = {
               function(cmp)
                  if cmp.is_visible() then
                     return cmp.select_next()
                  else
                     return cmp.snippet_forward()
                  end
               end,
               "snippet_forward",
               "fallback",
            },
            ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
         },
         signature = {
            enabled = true,
            window = {
               border = "single",
            },
         },
      },
      config = function(_, opts)
         require("blink.cmp").setup(opts)
      end,
   },
}
