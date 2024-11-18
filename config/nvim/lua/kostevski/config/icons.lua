local icons = {
   diagnostics = {
      Error = " ",
      Warn = " ",
      Hint = " ",
      Info = " ",
   },
   git = {
      signs = {
         add = { text = "▎" },
         change = { text = "▎" },
         delete = { text = "" },
         topdelete = { text = "" },
         changedelete = { text = "▎" },
         untracked = { text = "▎" },
      },
      added = " ",
      modified = " ",
      removed = " ",
   },
   dap = {
      Stopped = { "󰁕 ", "DiagnosticWarn", "DapStoppedLine" },
      Breakpoint = " ",
      BreakpointCondition = " ",
      BreakpointRejected = { " ", "DiagnosticError" },
      LogPoint = ".>",
   },
   kinds = {
      Array = " ",
      Boolean = "󰨙 ",
      Class = " ",
      Codeium = "󰘦 ",
      Color = " ",
      Control = " ",
      Collapsed = " ",
      Constant = "󰏿 ",
      Constructor = " ",
      Copilot = " ",
      Enum = " ",
      EnumMember = " ",
      Event = " ",
      Field = " ",
      File = " ",
      Folder = " ",
      Function = "󰊕 ",
      Interface = " ",
      Key = " ",
      Keyword = " ",
      Method = "󰊕 ",
      Module = " ",
      Namespace = "󰦮 ",
      Null = " ",
      Number = "󰎠 ",
      Object = " ",
      Operator = " ",
      Package = " ",
      Property = " ",
      Reference = " ",
      Snippet = " ",
      String = " ",
      Struct = "󰆼 ",
      TabNine = "󰏚 ",
      Text = " ",
      TypeParameter = " ",
      Unit = " ",
      Value = " ",
      Variable = "󰀫 ",
   },
   kind_filter = {
      default = {
         "Class",
         "Constructor",
         "Enum",
         "Field",
         "Function",
         "Interface",
         "Method",
         "Module",
         "Namespace",
         "Package",
         "Property",
         "Struct",
         "Trait",
      },
      markdown = false,
      help = false,
      lua = {
         "Class",
         "Constructor",
         "Enum",
         "Field",
         "Function",
         "Interface",
         "Method",
         "Module",
         "Namespace",
         "Property",
         "Struct",
         "Trait",
      },
   },
   misc = {
      dots = "󰇘",
   },
}

function icons.get_kind_filter(buf)
   buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
   local ft = vim.bo[buf].filetype
   if icons.kind_filter == false then
      return
   end
   if icons.kind_filter[ft] == false then
      return
   end
   if type(icons.kind_filter[ft]) == "table" then
      return icons.kind_filter[ft]
   end
   ---@diagnostic disable-next-line: return-type-mismatch
   return type(icons.kind_filter) == "table"
         and type(icons.kind_filter.default) == "table"
         and icons.kind_filter.default
      or nil
end
return icons
