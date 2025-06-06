return {
   {
      "nvim-neotest/neotest",
      dependencies = {
         "nvim-neotest/nvim-nio",
         "nvim-lua/plenary.nvim",
         "antoinemadec/FixCursorHold.nvim",
         "nvim-treesitter/nvim-treesitter",
      },
      keys = {
         { "<leader>n", "", desc = "+test" },
         {
            "<leader>nt",
            function()
               require("neotest").run.run(vim.fn.expand("%"))
            end,
            desc = "Run File (Neotest)",
         },
         {
            "<leader>nT",
            function()
               require("neotest").run.run(vim.uv.cwd())
            end,
            desc = "Run All Test Files (Neotest)",
         },
         {
            "<leader>nr",
            function()
               require("neotest").run.run()
            end,
            desc = "Run Nearest (Neotest)",
         },
         {
            "<leader>nl",
            function()
               require("neotest").run.run_last()
            end,
            desc = "Run Last (Neotest)",
         },
         {
            "<leader>ns",
            function()
               require("neotest").summary.toggle()
            end,
            desc = "Toggle Summary (Neotest)",
         },
         {
            "<leader>no",
            function()
               require("neotest").output.open({ enter = true, auto_close = true })
            end,
            desc = "Show Output (Neotest)",
         },
         {
            "<leader>nO",
            function()
               require("neotest").output_panel.toggle()
            end,
            desc = "Toggle Output Panel (Neotest)",
         },
         {
            "<leader>nS",
            function()
               require("neotest").run.stop()
            end,
            desc = "Stop (Neotest)",
         },
         {
            "<leader>nw",
            function()
               require("neotest").watch.toggle(vim.fn.expand("%"))
            end,
            desc = "Toggle Watch (Neotest)",
         },
      },
      opts = {
         -- Can be a list of adapters like what neotest expects,
         -- or a list of adapter names,
         -- or a table of adapter names, mapped to adapter configs.
         -- The adapter will then be automatically loaded with the config.
         adapters = {},
         -- Example for loading neotest-golang with a custom config
         -- adapters = {
         --   ["neotest-golang"] = {
         --     go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
         --     dap_go_enabled = true,
         --   },
         -- },
         status = { virtual_text = true },
         output = { open_on_run = true },
      },
      config = function(_, opts)
         local neotest_ns = vim.api.nvim_create_namespace("neotest")
         vim.diagnostic.config({
            virtual_text = {
               format = function(diagnostic)
                  -- Replace newline and tab characters with space for more compact diagnostics
                  local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
                  return message
               end,
            },
         }, neotest_ns)

         if opts.adapters then
            local adapters = {}
            for name, config in pairs(opts.adapters or {}) do
               if type(name) == "number" then
                  if type(config) == "string" then
                     config = require(config)
                  end
                  adapters[#adapters + 1] = config
               elseif config ~= false then
                  local adapter = require(name)
                  if type(config) == "table" and not vim.tbl_isempty(config) then
                     local meta = getmetatable(adapter)
                     if adapter.setup then
                        adapter.setup(config)
                     elseif adapter.adapter then
                        adapter.adapter(config)
                        adapter = adapter.adapter
                     elseif meta and meta.__call then
                        adapter = adapter(config)
                     else
                        error("Adapter " .. name .. " does not support setup")
                     end
                  end
                  adapters[#adapters + 1] = adapter
               end
            end
            opts.adapters = adapters
         end

         require("neotest").setup(opts)
      end,
   },
   {
      "mfussenegger/nvim-dap",
      optional = true,
    -- stylua: ignore
    keys = {
      { "<leader>td", function() require("neotest").run.run({strategy = "dap"}) end, desc = "Debug Nearest" },
   },
   },
}
