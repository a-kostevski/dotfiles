---@class Lsp
---@field private _supports_method table<string, table>
---@field private _cache table<string, any>
---@field public words LspWords Words highlighting functionality
---@field public handlers LspHandlers LSP handlers
---@field public capabilities LspCapabilities LSP capabilities management
local Lsp = {
   _supports_method = {},
   _cache = {},
   words = {
      enabled = false,
      ns = vim.api.nvim_create_namespace("vim_lsp_references"),
   },
}

---Gets LSP clients with specified options
---@param opts {bufnr?: number, method?: string, filter?: function} Options for filtering clients
---@return table[] Array of LSP clients
---@example
--- -- Get all clients for current buffer
--- local clients = Lsp.get_clients({ bufnr = 0 })
--- 
--- -- Get clients supporting formatting
--- local formatting_clients = Lsp.get_clients({
---    filter = function(client)
---       return client.supports_method("textDocument/formatting")
---    end
--- })
function Lsp.get_clients(opts)
   opts = opts or {}
   local ok, clients = pcall(vim.lsp.get_clients, opts)
   if not ok then
      vim.notify("Failed to get LSP clients: " .. clients, vim.log.levels.ERROR)
      return {}
   end
   return opts.filter and vim.tbl_filter(opts.filter, clients) or clients
end

--- Prints debug information about LSP clients and their capabilities
function Lsp.debug_capabilities()
   local clients = Lsp.get_clients()
   for _, client in ipairs(clients) do
      print("Client: " .. client.name)
      print("  ID: " .. client.id)
      print("  Root Directory: " .. (client.config.root_dir or "N/A"))
      print("  Capabilities:")
      print(vim.inspect(client.server_capabilities))
      print("  Attached Buffers: " .. vim.inspect(client.attached_buffers))
      print("  Workspace Folders: " .. vim.inspect(client.workspace_folders))
   end
end

---@param buf number Buffer number
---@param method string|string[] LSP method or array of methods
---@return boolean True if any specified method is supported
function Lsp.has(buf, method)
   if type(method) == "table" then
      for _, m in ipairs(method) do
         if Lsp.has(buf, m) then
            return true
         end
      end
      return false
   end

   method = method:find("/") and method or "textDocument/" .. method
   local clients = Lsp.get_clients({ bufnr = buf })

   for _, client in ipairs(clients) do
      if client.supports_method(method) then
         return true
      end
   end
   return false
end

---@param on_attach function
---@param name string|nil
---@return number Autocmd
function Lsp.on_attach(on_attach, name)
   return vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
         local buf = args.buf
         local client = vim.lsp.get_client_by_id(args.data.client_id)

         if client and (not name or client.name == name) then
            return on_attach(client, buf)
         end
      end,
   })
end

---@param client table LSP client
---@param buf number Buffer number
function Lsp._check_methods(client, buf)
   if not vim.api.nvim_buf_is_valid(buf) then
      return
   end

   if not vim.bo[buf].buflisted then
      return
   end

   if vim.bo[buf].buftype == "nofile" then
      return
   end

   for method, clients in pairs(Lsp._supports_method) do
      clients[client] = clients[client] or {}
      if not clients[client][buf] then
         if client.supports_method and client.supports_method(method, { bufnr = buf }) then
            clients[client][buf] = true
            vim.api.nvim_exec_autocmds("User", {
               pattern = "LspSupportsMethod",
               data = { client_id = client.id, buffer = buf, method = method },
            })
         end
      end
   end
end

--- Sets up LSP functionality and handlers
function Lsp.setup()
   local register_capability = vim.lsp.handlers["client/registerCapability"]
   vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
      local ret = register_capability(err, res, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client then
         for buffer in pairs(client.attached_buffers) do
            vim.api.nvim_exec_autocmds("User", {
               pattern = "LspDynamicCapability",
               data = { client_id = client.id, buffer = buffer },
            })
         end
      end
      return ret
   end

   Lsp.on_attach(Lsp._check_methods)
   Lsp.on_dynamic_capability(Lsp._check_methods)
end

---@param fn function
---@param opts table|nil
---@return number Autocmd
function Lsp.on_dynamic_capability(fn, opts)
   return vim.api.nvim_create_autocmd("User", {
      pattern = "LspDynamicCapability",
      group = opts and opts.group or nil,
      callback = function(args)
         local client = vim.lsp.get_client_by_id(args.data.client_id)
         local buffer = args.data.buffer
         if client then
            return fn(client, buffer)
         end
      end,
   })
end

---@param method string
---@param fn function
---@return number Autocmd ID
function Lsp.on_supports_method(method, fn)
   Lsp._supports_method[method] = Lsp._supports_method[method] or setmetatable({}, { __mode = "k" })
   return vim.api.nvim_create_autocmd("User", {
      pattern = "LspSupportsMethod",
      callback = function(args)
         local client = vim.lsp.get_client_by_id(args.data.client_id)
         local buffer = args.data.buffer
         if client and method == args.data.method then
            return fn(client, buffer)
         end
      end,
   })
end

function Lsp.rename_file()
   local buf = vim.api.nvim_get_current_buf()
   local old = vim.api.nvim_buf_get_name(buf)
   local root = vim.fn.getcwd()
   
   if not vim.api.nvim_buf_is_valid(buf) then
      vim.notify("Invalid buffer", vim.log.levels.ERROR)
      return
   end
   
   if not old or old == "" then
      vim.notify("No file name for current buffer", vim.log.levels.ERROR)
      return
   end

   assert(old:find(root, 1, true) == 1, "File not in project root")
   local extra = old:sub(#root + 2)
   vim.ui.input({
      prompt = "New File Name: ",
      default = extra,
      completion = "file",
   }, function(new)
      if not new or new == "" or new == extra then
         return
      end
      new = require("lazy.core.util").norm(root .. "/" .. new)
      vim.fn.mkdir(vim.fn.fnamemodify(new, ":h"), "p")
      Lsp.on_rename(old, new, function()
         vim.fn.rename(old, new)
         vim.cmd.edit(new)
         vim.api.nvim_buf_delete(buf, { force = true })
         vim.fn.delete(old)
      end)
   end)
end

--- Handles LSP file rename operations
---@param from string Original file path
---@param to string New file path
---@param callback function|nil Optional callback after rename
function Lsp.on_rename(from, to, callback)
   local changes = {
      files = {
         {
            oldUri = vim.uri_from_fname(from),
            newUri = vim.uri_from_fname(to),
         },
      },
   }
   local clients = Lsp.get_clients()
   for _, client in ipairs(clients) do
      if client.supports_method("workspace/willRenameFiles") then
         local resp = client.request_sync("workspace/willRenameFiles", changes, 1000)
         if resp and resp.result then
            vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
         end
      end
   end

   if callback then
      callback()
   end

   for _, client in ipairs(clients) do
      if client.supports_method("workspace/didRenameFiles") then
         client.notify("workspace/didRenameFiles", changes)
      end
   end
end

--- Gets default LSP capabilities with optional extensions
---@param opts table Configuration options
---@return table LSP capabilities
function Lsp.default_capabilities(opts)
   local has_blink, blink = pcall(require, "blink.cmp")
   local capabilities = vim.tbl_deep_extend(
      "force",
      {},
  ---    vim.lsp.protocol.make_client_capabilities(),
      has_blink and blink.get_lsp_capabilities() or {},
      opts.capabilities or {}
   )
   return capabilities
end

--- Gets LSP server configuration
---@param server string Server name
---@return table|nil Server configuration
function Lsp.get_config(server)
   local configs = require("lspconfig.configs")
   return rawget(configs, server)
end

--- Checks if an LSP
---@param server string Server name
---@return boolean True if server is enabled
function Lsp.is_enabled(server)
   local c = Lsp.get_config(server)
   return c and c.enabled ~= false
end

--- Namespace for word highlighting functionality
Lsp.words = {}
Lsp.words.enabled = false
Lsp.words.ns = vim.api.nvim_create_namespace("vim_lsp_references")

--- Sets up word highlighting functionality
---@param opts table|nil Configuration options
function Lsp.words.setup(opts)
   opts = opts or {}
   if not opts.enabled then
      return
   end
   Lsp.words.enabled = true

   local handler = vim.lsp.handlers["textDocument/documentHighlight"]
   vim.lsp.handlers["textDocument/documentHighlight"] = function(err, result, ctx, config)
      if not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
         return
      end
      vim.lsp.buf.clear_references()
      return handler(err, result, ctx, config)
   end

   Lsp.on_supports_method("textDocument/documentHighlight", function(_, buf)
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "CursorMoved", "CursorMovedI" }, {
         group = vim.api.nvim_create_augroup("lsp_word_" .. buf, { clear = true }),
         buffer = buf,
         callback = function(ev)
            local _, current = Lsp.words.get()
            if not current then
               if ev.event:find("CursorMoved") then
                  vim.lsp.buf.clear_references()
               elseif not require("kostevski.utils.cmp").visible() then
                  vim.lsp.buf.document_highlight()
               end
            end
         end,
      })
   end)
end

--- Gets current word highlights and cursor position
---@return table, number|nil List of highlighted words and current word index
function Lsp.words.get()
   local cursor = vim.api.nvim_win_get_cursor(0)
   local current, ret = nil, {}
   local extmarks = vim.api.nvim_buf_get_extmarks(0, Lsp.words.ns, 0, -1, { details = true })
   for _, extmark in ipairs(extmarks) do
      local w = {
         from = { extmark[2] + 1, extmark[3] },
         to = { extmark[4].end_row + 1, extmark[4].end_col },
      }
      ret[#ret + 1] = w
      if cursor[1] >= w.from[1] and cursor[1] <= w.to[1] and cursor[2] >= w.from[2] and cursor[2] <= w.to[2] then
         current = #ret
      end
   end
   return ret, current
end

--- Jumps between highlighted words
---@param count number Number of words to jump
---@param cycle boolean|nil Whether to cycle through words
function Lsp.words.jump(count, cycle)
   local words, idx = Lsp.words.get()
   if not idx then
      return
   end
   idx = idx + count
   if cycle then
      idx = ((idx - 1) % #words) + 1
   else
      if idx < 1 or idx > #words then
         return
      end
   end
   local target = words[idx]
   if target then
      vim.api.nvim_win_set_cursor(0, target.from)
   end
end

--- Creates a formatter configuration
---@param opts table|nil Formatter options
---@return table Formatter configuration
function Lsp.formatter(opts)
   opts = opts or {}
   local filter = opts.filter or {}
   filter = type(filter) == "string" and { name = filter } or filter
   local ret = {
      name = "LSP",
      primary = true,
      priority = 1,
      format = function(buf)
         Lsp.format(Utils.merge({}, filter, { bufnr = buf }))
      end,
      sources = function(buf)
         local clients = Lsp.get_clients(Utils.merge({}, filter, { bufnr = buf }))
         local ret = vim.tbl_filter(function(client)
            return client.supports_method("textDocument/formatting")
               or client.supports_method("textDocument/rangeFormatting")
         end, clients)
         return vim.tbl_map(function(client)
            return client.name
         end, ret)
      end,
   }
   return Utils.merge(ret, opts)
end

--- Formats buffer using LSP or conform.nvim
---@param opts table|nil Formatting options
function Lsp.format(opts)
   opts = vim.tbl_deep_extend(
      "force",
      {},
      opts or {},
      Utils.plugin.opts("nvim-lspconfig").format or {},
      Utils.plugin.opts("conform.nvim").format or {}
   )
   local ok, conform = pcall(require, "conform")
   if ok then
      opts.formatters = {}
      conform.format(opts)
   else
      vim.lsp.buf.format(opts)
   end
end

--- Metatable for LSP code actions
Lsp.action = setmetatable({}, {
   __index = function(_, action)
      return function()
         vim.lsp.buf.code_action({
            apply = true,
            context = {
               only = { action },
               diagnostics = {},
            },
         })
      end
   end,
})

--- Executes LSP command
---@param opts table Command options including command name and arguments
---@return any Command result
function Lsp.execute(opts)
   local params = {
      command = opts.command,
      arguments = opts.arguments,
   }
   if opts.open then
      require("trouble").open({
         mode = "lsp_command",
         params = params,
      })
   else
      return vim.lsp.buf_request(0, "workspace/executeCommand", params, opts.handler)
   end
end

return Lsp
