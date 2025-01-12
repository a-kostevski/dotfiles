---@class Keys
---@field keys KeymapDefinition[]
local Keys = {}

---@alias LSPCapability string
---@alias KeymapHandler function|string
---@class KeymapDefinition
---@field [1] string The keybinding
---@field [2] KeymapHandler The handler
---@field desc string Description
---@field mode? string|string[] Vim modes
---@field has? LSPCapability|LSPCapability[] Required capabilities
---@field cond? function Optional condition function
---@field nowait? boolean Don't wait for more keys

Keys.keys = {

   { "<leader>cl", "<cmd>LspInfo<cr>", desc = "Lsp Info" },
   { "gd", vim.lsp.buf.definition, desc = "Goto Definition", has = "definition" },
   { "gr", vim.lsp.buf.references, desc = "References", nowait = true },
   { "gI", vim.lsp.buf.implementation, desc = "Goto Implementation" },
   { "gy", vim.lsp.buf.type_definition, desc = "Goto Type Definition" },
   { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration" },
   {
      "K",
      function()
         vim.lsp.buf.hover()
      end,
      desc = "Hover",
   },
   {
      "gK",
      vim.lsp.buf.signature_help,
      desc = "Signature Help",
      has = "signatureHelp",
   },
   {
      "<c-k>",
      vim.lsp.buf.signature_help,
      mode = "i",
      desc = "Signature Help",
      has = "signatureHelp",
   },
   { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
   { "<leader>cA", Utils.lsp.action.source, desc = "Source Action", has = "codeAction" },
   { "<leader>cc", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "v" }, has = "codeLens" },
   { "<leader>cC", vim.lsp.codelens.refresh, desc = "Refresh & Display Codelens", mode = { "n" }, has = "codeLens" },
   { "<leader>cr", vim.lsp.buf.rename, desc = "Rename", has = "rename" },
   {
      "<leader>cR",
      function()
         Utils.lsp.rename_file()
      end,
      desc = "Rename File",
      mode = { "n" },
      has = { "workspace/didRenameFiles", "workspace/willRenameFiles" },
   },
   {
      "]]",
      function()
         Utils.lsp.words.jump(vim.v.count1)
      end,
      has = "documentHighlight",
      desc = "Next Reference",
      cond = function()
         return Utils.lsp.words.enabled
      end,
   },
   {
      "[[",
      function()
         Utils.lsp.words.jump(-vim.v.count1)
      end,
      has = "documentHighlight",
      desc = "Prev Reference",
      cond = function()
         return Utils.lsp.words.enabled
      end,
   },
   {
      "<a-n>",
      function()
         Utils.lsp.words.jump(vim.v.count1, true)
      end,
      has = "documentHighlight",
      desc = "Next Reference",
      cond = function()
         return Utils.lsp.words.enabled
      end,
   },
   {
      "<a-p>",
      function()
         Utils.lsp.words.jump(-vim.v.count1, true)
      end,
      has = "documentHighlight",
      desc = "Prev Reference",
      cond = function()
         return Utils.lsp.words.enabled
      end,
   },
}

---Normalize modes to array
---@param mode? string|string[]
---@return string[]
local function normalize_modes(mode)
   return type(mode) == "table" and mode or { mode or "n" }
end

---@param lhs string
---@param rhs function|string
---@param opts? table
function Keys.map(lhs, rhs, opts)
   vim.validate({
      lhs = { lhs, "string" },
      rhs = { rhs, { "function", "string" } },
      opts = { opts, "table", true },
   })

   opts = opts or {}
   local keymap_def = {
      lhs,
      rhs,
      desc = opts.desc,
      mode = opts.mode or "n",
      nowait = opts.nowait,
      has = opts.has,
      cond = opts.cond,
   }
   table.insert(Keys.keys, keymap_def)
end

---Apply keymap safely with error handling
---@param keymap KeymapDefinition
---@param opts table
---@return boolean
local function apply_keymap(keymap, opts)
   local modes = normalize_modes(keymap.mode)
   for _, mode in ipairs(modes) do
      local success, err = pcall(vim.keymap.set, mode, keymap[1], keymap[2], opts)
      if not success then
         vim.notify(string.format("Failed to map %s in mode %s: %s", keymap[1], mode, err), vim.log.levels.ERROR)
         return false
      end
   end
   return true
end

---Attach keymaps to buffer
---@param client table LSP client
---@param buffer number Buffer number
function Keys.on_attach(client, buffer)
   -- Use Utils.lsp.has for capability checking
   for _, keymap in ipairs(Keys.keys) do
      -- Check capabilities first
      if keymap.has and not Utils.lsp.has(buffer, keymap.has) then
         goto continue
      end

      -- Check conditions
      if keymap.cond and not keymap.cond() then
         goto continue
      end

      local opts = {
         noremap = true,
         silent = true,
         buffer = buffer,
         desc = keymap.desc,
         nowait = keymap.nowait,
      }

      apply_keymap(keymap, opts)
      ::continue::
   end
end

---@param buffer number
function Keys.detach(buffer)
   if not vim.api.nvim_buf_is_valid(buffer) then
      return
   end

   for _, keymap in ipairs(Keys.keys) do
      local modes = normalize_modes(keymap.mode)
      for _, mode in ipairs(modes) do
         pcall(vim.keymap.del, mode, keymap[1], { buffer = buffer })
      end
   end
end

function Keys.setup()
   Utils.lsp.on_attach(Keys.on_attach)

   vim.api.nvim_create_autocmd("LspDetach", {
      callback = function(args)
         Keys.detach(args.buf)
      end,
   })
end

function Keys.debug()
   for _, client in pairs(Utils.lsp.get_clients()) do
      print(string.format("LSP Client: %s (id: %d)", client.name, client.id))
      for _, keymap in ipairs(Keys.keys) do
         local has_cap = not keymap.has or Utils.lsp.has(client.id, keymap.has)
         if has_cap then
            print(
               string.format(
                  "  %s -> %s (%s)",
                  keymap[1],
                  type(keymap[2]) == "function" and "function" or keymap[2],
                  keymap.desc or "no description"
               )
            )
         end
      end
   end
end

-- Create debug command
vim.api.nvim_create_user_command("DebugLspKeys", Keys.debug, {})

return Keys
