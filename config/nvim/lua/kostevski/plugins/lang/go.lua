return {
   -- LSP Configuration
   {
      "mason",
      optional = true,
      opts = { ensure_installed = { "goimports", "gofumpt" } },
   },

   -- Formatter Configuration
   {
      "stevearc/conform.nvim",
      opts = {
         formatters_by_ft = {
            go = { "gofumpt", "goimports" },
         },
      },
   },

   -- Linter Configuration
   {
      "mfussenegger/nvim-lint",
      opts = {
         linters_by_ft = {
            go = { "golangci-lint" },
         },
      },
   },

   -- DAP Configuration
   {
      "mfussenegger/nvim-dap",
      optional = true,
      opts = function()
         require("dap-go").setup()
         return {
            adapters = {
               delve = {
                  type = "server",
                  port = "${port}",
                  executable = {
                     command = "dlv",
                     args = { "dap", "-l", "127.0.0.1:${port}" },
                  },
               },
            },
         }
      end,
   },

   -- Neotest
   {
      "nvim-neotest/neotest",
      optional = true,
      dependencies = {
         "fredrikaverpil/neotest-golang",
      },
      opts = {
         adapters = {
            ["neotest-golang"] = {
               -- Here we can set options for neotest-golang, e.g.
               -- go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
               dap_go_enabled = true, -- requires leoluz/nvim-dap-go
            },
         },
      },
   },
   -- Additional Tools
   {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
         if type(opts.ensure_installed) == "table" then
            vim.list_extend(opts.ensure_installed, { "go", "gomod", "gowork", "gosum" })
         end
      end,
   },
   {
      "phelipetls/vim-hugo",
   },
}
