return {
   {
      "saghen/blink.cmp",
      build = "cargo build --release",
      version = "*",
      event = "InsertEnter",
      dependencies = {
         "saghen/blink.compat",
         "rafamadriz/friendly-snippets",
      },
      opts_extend = {
         "sources.completion.enabled_providers",
         "sources.compat",
      },
      opts = {
         accept = {
            auto_brackets = {
               enabled = true,
            },
         },
         keymap = {
            preset = "enter",
            ["<Tab>"] = {
               function(cmp)
                  if cmp.is_in_snippet() then
                     return cmp.accept()
                  else
                     return cmp.select_next()
                  end
               end,
               "snippet_forward",
               "fallback",
            },
            ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
         },
         kind_icons = Utils.ui.icons.kinds,
         nerd_font_variant = "mono",
         sources = {
            compat = {},
            completion = {
               enabled_providers = {
                  "lsp",
                  "path",
                  "snippets",
                  "buffer",
               },
            },
         },
         highlight = {
            ns = vim.api.nvim_create_namespace("blink_cmp"),
            use_nvim_cmp_as_default = true,
         },
         trigger = {
            completion = {
               blocked_trigger_characters = { " ", "\n", "\t", "," },
            },
            signature_help = {
               enabled = true,
            },
            show_in_snippet = true,
         },
         windows = {
            autocomplete = {
               border = "rounded",
               min_width = 25,
               max_height = 30,
               scrollbar = true,
               selection = "manual",
               direction_priority = { "s", "n" },
               draw = function(ctx)
                  local icon = ctx.kind_icon
                  local icon_hl = vim.api.nvim_get_hl(0, { name = "BlinkCmpKind" }) and "BlinkCmpKind" .. ctx.kind
                     or "BlinkCmpKind"
                  local source, client = ctx.item.source_id, ctx.item.client_id

                  if client and vim.lsp.get_client_by_id(client).name then
                     source = vim.lsp.get_client_by_id(client).name
                  else
                     source = ctx.item.source_name
                  end

                  return {
                     {
                        " " .. ctx.item.label .. " ",
                        fill = true,
                        hl_group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "BlinkCmpLabel",
                        max_width = 35,
                     },
                     {
                        icon .. ctx.icon_gap .. ctx.kind .. " ",
                        fill = true,
                        hl_group = icon_hl,
                        max_width = 25,
                     },
                     {
                        " [" .. source .. "] ",
                        fill = true,
                        hl_group = ctx.deprecated and "BlinkCmpLabelDeprecated" or "CmpItemMenu",
                        max_width = 15,
                     },
                  }
               end,
               winblend = vim.o.pumblend,
            },
            documentation = {
               auto_show = true,
               auto_show_delay_ms = 100,
            },
            signature_help = {
               border = "rounded",
            },
         },
      },
      config = function(_, opts)
         local enabled = opts.sources.completion.enabled_providers
         for _, source in ipairs(opts.sources.compat or {}) do
            opts.sources.providers[source] = vim.tbl_deep_extend(
               "force",
               { name = source, module = "blink.compat.source" },
               opts.sources.providers[source] or {}
            )
            if type(enabled) == "table" and not vim.tbl_contains(enabled, source) then
               table.insert(enabled, source)
            end
         end
         require("blink.cmp").setup(opts)
      end,
   },
}
