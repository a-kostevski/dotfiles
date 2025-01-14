local icons = {
   borders = {
      dashed = { "┄", "┊", "┄", "┊", "╭", "╮", "╯", "╰" },
      double = { "═", "║", "═", "║", "╔", "╗", "╝", "╚" },
      single = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      blocks = { "▀", "▐", "▄", "▌", "▛", "▜", "▟", "▙" },
      blocky = { "▀", "▐", "▄", "▌", "▄", "▄", "▓", "▀" },
   },
   diagnostics = {
      ERROR = " ",
      WARN = " ",
      HINT = " ",
      INFO = " ",
   },
   git = {
      branch = "",
      commit = "",
      add = " ",
      change = "▕",
      mod = "",
      remove = "",
      delete = "🮉",
      topdelete = "🮉",
      changedelete = "🮉",
      untracked = "▕",
      ignore = "",
      rename = "",
      diff = "",
      repo = "",
      symbol = "",
      unstaged = "󰛄",
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
   keys = {
      Up = " ",
      Down = " ",
      Left = " ",
      Right = " ",
      C = "󰘴 ",
      M = "󰘵 ",
      D = "󰘳 ",
      S = "󰘶 ",
      CR = "󰌑 ",
      Esc = "󱊷 ",
      ScrollWheelDown = "󱕐 ",
      ScrollWheelUp = "󱕑 ",
      NL = "󰌑 ",
      BS = "󰁮",
      Space = "󱁐 ",
      Tab = "󰌒 ",
      F1 = "󱊫",
      F2 = "󱊬",
      F3 = "󱊭",
      F4 = "󱊮",
      F5 = "󱊯",
      F6 = "󱊰",
      F7 = "󱊱",
      F8 = "󱊲",
      F9 = "󱊳",
      F10 = "󱊴",
      F11 = "󱊵",
      F12 = "󱊶",
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
      breadcrumb = "»",
      separator = "➜",
      group = ">",
      ellipsis = "…",
      dots = "󰇘",
      spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
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
   return type(icons.kind_filter) == "table"
         and type(icons.kind_filter.default) == "table"
         and icons.kind_filter.default
      or nil
end
return icons
