-- Example: Ruby language configuration using the new utility module
-- This demonstrates how easy it is to add comprehensive language support

local lang = require("kostevski.utils.lang")

-- Method 1: Using the simple preset with overrides
return lang.register(lang.create_simple("ruby", {
   filetypes = { "ruby", "erb", "haml", "slim" },
   lsp_server = "ruby_lsp",
   formatters = {
      list = { "rubocop", "prettier" },
      tools = { "rubocop", "prettier" },
      config = {
         rubocop = {
            -- Custom rubocop configuration
            command = "rubocop",
            args = { "--auto-correct", "--stdin", "$FILENAME", "--format", "quiet" },
         },
      },
   },
   linters = {
      list = { "rubocop" },
      tools = { "rubocop" },
   },
   treesitter_parsers = { "ruby", "erb" },
   root_patterns = { "Gemfile", ".rubocop.yml", ".git" },
   test_adapters = { "olimorris/neotest-rspec" },
   settings = {
      expandtab = true,
      shiftwidth = 2,
      tabstop = 2,
      softtabstop = 2,
   },
   additional_plugins = {
      -- Rails development support
      {
         "tpope/vim-rails",
         ft = { "ruby", "eruby" },
      },
      -- Ruby text objects
      {
         "RRethy/nvim-treesitter-textsubjects",
         ft = "ruby",
      },
   },
}))

-- Method 2: Full manual configuration for more control
-- return lang.register({
--    name = "ruby",
--    filetypes = { "ruby", "erb", "haml", "slim" },
--    root_patterns = { "Gemfile", ".rubocop.yml", ".git" },
--    lsp_server = {
--       name = "ruby_lsp",
--       config = {
--          init_options = {
--             formatter = "rubocop",
--             linters = { "rubocop" },
--          },
--       },
--    },
--    formatters = {
--       list = { "rubocop" },
--       tools = { "rubocop" },
--       config = {
--          rubocop = {
--             command = "rubocop",
--             args = { "--auto-correct", "--stdin", "$FILENAME", "--format", "quiet" },
--             stdin = true,
--          },
--       },
--    },
--    linters = {
--       list = { "rubocop" },
--       tools = { "rubocop" },
--       config = {
--          rubocop = {
--             cmd = "rubocop",
--             args = { "--format", "json", "--stdin", "$FILENAME" },
--             stdin = true,
--          },
--       },
--    },
--    dap = {
--       adapters = {
--          ruby = {
--             type = "executable",
--             command = "bundle",
--             args = { "exec", "rdbg", "-n", "--open", "--port", "${port}", "-c", "--", "bundle", "exec" },
--          },
--       },
--       configurations = {
--          ruby = {
--             {
--                type = "ruby",
--                name = "Debug current file",
--                request = "launch",
--                program = "${file}",
--             },
--             {
--                type = "ruby",
--                name = "Run rails server",
--                request = "launch",
--                program = "bin/rails",
--                args = { "server" },
--             },
--          },
--       },
--    },
--    test_adapters = { "olimorris/neotest-rspec" },
--    treesitter_parsers = { "ruby", "erb" },
--    mason_packages = { "ruby-lsp", "rubocop", "erb-formatter", "erb-lint" },
--    settings = {
--       expandtab = true,
--       shiftwidth = 2,
--       tabstop = 2,
--       softtabstop = 2,
--    },
--    additional_plugins = {
--       {
--          "tpope/vim-rails",
--          ft = { "ruby", "eruby" },
--       },
--       {
--          "vim-ruby/vim-ruby",
--          ft = "ruby",
--       },
--    },
-- })
