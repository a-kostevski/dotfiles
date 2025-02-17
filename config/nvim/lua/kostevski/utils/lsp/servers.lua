local M = {}

-- Common LSP server configurations
M.servers = {
   lua_ls = {
      settings = {
         Lua = {
            diagnostics = {
               globals = { "vim" }
            }
         }
      }
   },
   tsserver = {},
   rust_analyzer = {},
   -- Add more server configs
}

function M.setup()
   local lspconfig = require("lspconfig")
   local capabilities = require("kostevski.utils.lsp.capabilities").get_capabilities()

   for server, config in pairs(M.servers) do
      config.capabilities = capabilities
      lspconfig[server].setup(config)
   end
end

return M 