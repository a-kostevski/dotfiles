local Keys = {}
Keys.keys = {
   { "<leader>cl", "<cmd>LspInfo<cr>", desc = "Lsp Info" },
   { "gd", vim.lsp.buf.definition, desc = "Goto Definition", has = "definition" },
   { "gr", vim.lsp.buf.references, desc = "References", nowait = true },
   { "gI", vim.lsp.buf.implementation, desc = "Goto Implementation" },
   { "gy", vim.lsp.buf.type_definition, desc = "Goto Type Definition" },
   { "gD", vim.lsp.buf.declaration, desc = "Goto Declaration" },
   { "K", vim.lsp.buf.hover, desc = "Hover" },
   { "gK", vim.lsp.buf.signature_help, desc = "Signature Help", has = "signatureHelp" },
   { "<c-k>", vim.lsp.buf.signature_help, mode = "i", desc = "Signature Help", has = "signatureHelp" },
   { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
   { "<leader>cc", vim.lsp.codelens.run, desc = "Run Codelens", mode = { "n", "v" }, has = "codeLens" },
   { "<leader>cC", vim.lsp.codelens.refresh, desc = "Refresh & Display Codelens", mode = { "n" }, has = "codeLens" },
   {
      "<leader>cR",
      Utils.lsp.rename_file,
      desc = "Rename File",
      mode = { "n" },
      has = { "workspace/didRenameFiles", "workspace/willRenameFiles" },
   },
   { "<leader>cr", vim.lsp.buf.rename, desc = "Rename", has = "rename" },
   { "<leader>cA", Utils.lsp.action.source, desc = "Source Action", has = "codeAction" },
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

function Keys.on_attach(_, buffer)
   for _, keymap in ipairs(Keys.keys) do
      local mode = keymap.mode or "n"
      local opts = { noremap = true, silent = true, buffer = buffer, desc = keymap.desc, nowait = keymap.nowait }

      -- Check if the client has the required capability
      local has = true
      if keymap.has then
         has = Utils.lsp.has(buffer, keymap.has)
      end

      -- Check any additional conditions
      local cond = true
      if keymap.cond then
         cond = keymap.cond()
      end

      if has and cond then
         vim.keymap.set(mode, keymap[1], keymap[2], opts)
      end
   end
end

return Keys
