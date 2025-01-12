return {
   {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      event = "InsertEnter",
      name = "copilot.lua",
      build = ":Copilot auth",
      opts = {
         suggestion = { enabled = false },
         panel = { enabled = false },
         filetypes = {
            markdown = true,
            help = true,
         },
      },
   },
   --    "saghen/blink.cmp",
   --    optional = true,
   --    dependencies = {
   --       {
   --          "giuxtaposition/blink-cmp-copilot",
   --          enabled = vim.g.ai_suggestions_enabled,
   --          specs = {
   --             {
   --                "blink.cmp",
   --                optional = true,
   --                opts = {
   --                   sources = {
   --                      providers = {
   --                         copilot = { name = "copilot", module = "blink-cmp-copilot" },
   --                      },
   --                      completion = {
   --                         enabled_providers = { "copilot" },
   --                      },
   --                   },
   --                },
   --             },
   --          },
   --       },
   --    },
   -- },
}
