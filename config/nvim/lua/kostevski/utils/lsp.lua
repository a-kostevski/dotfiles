local Lsp = {}

function Lsp.get_clients(opts)
   opts = opts or {}
   local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
   local clients = vim.lsp.get_clients({ bufnr = bufnr })

   if opts.filter then
      clients = vim.tbl_filter(opts.filter, clients)
   end

   return clients
end

-- Function to check if any LSP client attached to the buffer supports a specific method
function Lsp.has(buffer, method)
   if type(method) == "table" then
      for _, m in ipairs(method) do
         if Lsp.has(buffer, m) then
            return true
         end
      end
      return false
   end

   method = method:find("/") and method or "textDocument/" .. method
   local clients = Lsp.get_clients({ bufnr = buffer })

   for _, client in ipairs(clients) do
      if client.supports_method(method) then
         return true
      end
   end
   return false
end

-- Function to set up an autocmd that triggers when an LSP client attaches to a buffer
function Lsp.on_attach(on_attach, name)
   return vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
         local buffer = args.buf
         local client = vim.lsp.get_client_by_id(args.data.client_id)

         if client and (not name or client.name == name) then
            return on_attach(client, buffer)
         end
      end,
   })
end
function Lsp._check_methods(client, buffer)
   -- Don't trigger on invalid buffers
   if not vim.api.nvim_buf_is_valid(buffer) then
      return
   end

   -- Don't trigger on non-listed buffers
   if not vim.bo[buffer].buflisted then
      return
   end

   -- Don't trigger on 'nofile' buffers
   if vim.bo[buffer].buftype == "nofile" then
      return
   end

   -- Iterate over the methods tracked in Lsp._supports_method
   for method, clients in pairs(Lsp._supports_method) do
      clients[client] = clients[client] or {}
      if not clients[client][buffer] then
         if client.supports_method and client.supports_method(method, { bufnr = buffer }) then
            clients[client][buffer] = true
            -- Trigger a custom autocommand when the client supports a method
            vim.api.nvim_exec_autocmds("User", {
               pattern = "LspSupportsMethod",
               data = { client_id = client.id, buffer = buffer, method = method },
            })
         end
      end
   end
end
Lsp._supports_method = {}
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
   -- Setup LSP default keymaps
   --   Lsp.default_keymaps()
   -- Attach to LSP events
   Lsp.on_attach(Lsp._check_methods)
   Lsp.on_dynamic_capability(Lsp._check_methods)
end
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
function Lsp.rename_file()
   local buf = vim.api.nvim_get_current_buf()
   local old = vim.api.nvim_buf_get_name(buf)
   local root = vim.fn.getcwd()
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

function Lsp.on_rename(from, to, rename)
   local changes = { files = { {
      oldUri = vim.uri_from_fname(from),
      newUri = vim.uri_from_fname(to),
   } } }
   local clients = Lsp.get_clients()
   for _, client in ipairs(clients) do
      if client.supports_method("workspace/willRenameFiles") then
         local resp = client.request_sync("workspace/willRenameFiles", changes, 1000, 0)
         if resp and resp.result ~= nil then
            vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
         end
      end
   end
   if rename then
      rename()
   end
   for _, client in ipairs(clients) do
      if client.supports_method("workspace/didRenameFiles") then
         client.notify("workspace/didRenameFiles", changes)
      end
   end
end

-- Function to check and trigger autocommands for supported LSP methods
function Lsp.default_capabilities(opts)
   local has_blink, blink = pcall(require, "blink.cmp")
   local capabilities = vim.tbl_deep_extend(
      "force",
      {},
      vim.lsp.protocol.make_client_capabilities(),
      has_blink and blink.get_lsp_capabilities() or {},
      opts.capabilities or {}
   )
   return capabilities
end

function Lsp.get_config(server)
   local configs = require("lspconfig.configs")
   return rawget(configs, server)
end

function Lsp.get_raw_config(server)
   local ok, ret = pcall(require, "lspconfig.configs." .. server)
   if ok then
      return ret
   end
   return require("lspconfig.server_configurations." .. server)
end
function Lsp.is_enabled(server)
   local c = Lsp.get_config(server)
   return c and c.enabled ~= false
end

function Lsp.on_supports_method(method, fn)
   Lsp._supports_method[method] = Lsp._supports_method[method] or setmetatable({}, { __mode = "k" })
   return vim.api.nvim_create_autocmd("User", {
      pattern = "LspSupportsMethod",
      callback = function(args)
         local client = vim.lsp.get_client_by_id(args.data.client_id)
         local buffer = args.data.buffer ---@type number
         if client and method == args.data.method then
            return fn(client, buffer)
         end
      end,
   })
end
Lsp.words = {}
Lsp.words.enabled = false
Lsp.words.ns = vim.api.nvim_create_namespace("vim_lsp_references")

-- Function to set up word highlighting based on LSP document highlights
function Lsp.words.setup(opts)
   opts = opts or {}
   if not opts.enabled then
      return
   end
   Lsp.words.enabled = true

   -- Override the default LSP handler for document highlights
   local handler = vim.lsp.handlers["textDocument/documentHighlight"]
   vim.lsp.handlers["textDocument/documentHighlight"] = function(err, result, ctx, config)
      if not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
         return
      end
      vim.lsp.buf.clear_references()
      return handler(err, result, ctx, config)
   end
   -- Set up autocmds to trigger document highlights
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

-- Function to create a formatter configuration for LSP formatting
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
function Lsp.execute(opts)
   local params = {
      command = opts.command,
      arguments = opts.arguments,
   }
   if opts.open then
      -- If 'open' is true, use the 'trouble' plugin to display the results
      require("trouble").open({
         mode = "lsp_command",
         params = params,
      })
   else
      -- Otherwise, send a 'workspace/executeCommand' request to the LSP server
      return vim.lsp.buf_request(0, "workspace/executeCommand", params, opts.handler)
   end
end
return Lsp
