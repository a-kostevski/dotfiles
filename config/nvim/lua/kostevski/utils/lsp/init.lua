-- Improve LSP module organization by adding proper type definitions
---@class LspModule
---@field clients LspClients
---@field handlers LspHandlers 
---@field words LspWords
---@field formatting LspFormatting
---@field capabilities LspCapabilities
---@field diagnostics LspDiagnostics
---@field status LspStatus
---@field progress LspProgress
local Lsp = {
   clients = require("kostevski.utils.lsp.clients"),
   handlers = require("kostevski.utils.lsp.handlers"),
   words = require("kostevski.utils.lsp.words"),
   formatting = require("kostevski.utils.lsp.formatting"),
   capabilities = require("kostevski.utils.lsp.capabilities"),
   diagnostics = require("kostevski.utils.lsp.diagnostics"),
   status = require("kostevski.utils.lsp.status"),
   progress = require("kostevski.utils.lsp.progress"),
}

-- Add health checks
function Lsp.check_health()
   local health = require("health")
   health.report_start("LSP")
   
   -- Check if nvim-lspconfig is installed
   local has_lspconfig = pcall(require, "lspconfig")
   if not has_lspconfig then
      health.report_error("nvim-lspconfig is not installed")
   else
      health.report_ok("nvim-lspconfig is installed")
   end
   
   -- Check active servers
   local active_clients = vim.lsp.get_active_clients()
   if #active_clients > 0 then
      health.report_ok(string.format("Found %d active LSP clients", #active_clients))
   else
      health.report_warn("No active LSP clients")
   end
end

return Lsp 