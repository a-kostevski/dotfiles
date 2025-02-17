local M = {}

local icons = {
   borders = {
      dashed = { "┄", "┊", "┄", "┊", "╭", "╮", "╯", "╰" },
      double = { "═", "║", "═", "║", "╔", "╗", "╝", "╚" },
      single = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      blocks = { "▀", "▐", "▄", "▌", "▛", "▜", "▟", "▙" },
      blocky = { "▀", "▐", "▄", "▌", "▄", "▄", "▓", "▀" },
   },
   diagnostics = {
      ERROR = " ", -- Alternatively: " "
      WARN = " ",
      HINT = "󰌶 ", -- Alternatively: " "
      INFO = " ", -- Alternatively: " "
   },
   git = {
      branch = "",
      commit = "",
      add = " ",
      change = "",
      mod = "",
      remove = " ",
      delete = "",
      topdelete = "",
      changedelete = "",
      untracked = "",
      ignore = "",
      rename = "",
      diff = "",
      repo = "",
      symbol = "",
      unstaged = "",
      modified = " ",
      removed = " ",
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
      group = "",
      ellipsis = "…",
      dots = "",
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

M.icons = icons

function M.foldtext()
   local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
   local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext()
   if not ret or type(ret) == "string" then
      ret = { { vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1], {} } }
   end
   table.insert(ret, { " " .. require("config.icons").misc.dots })
   if not vim.treesitter.foldtext then
      return table.concat(
         vim.tbl_map(function(line)
            return line[1]
         end, ret),
         " "
      )
   end
   return ret
end

function M.bufremove(buf)
   buf = buf or 0
   buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

   if vim.bo.modified then
      local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname()), "&Yes\n&No\n&Cancel")
      if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
         return
      end
      if choice == 1 then -- Yes
         vim.cmd.write()
      end
   end

   for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_call(win, function()
         if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
            return
         end
         -- Try using alternate buffer
         local alt = vim.fn.bufnr("#")
         if alt ~= buf and vim.fn.buflisted(alt) == 1 then
            vim.api.nvim_win_set_buf(win, alt)
            return
         end

         -- Try using previous buffer
         local has_previous = pcall(vim.cmd, "bprevious")
         if has_previous and buf ~= vim.api.nvim_win_get_buf(win) then
            return
         end

         -- Create new listed buffer
         local new_buf = vim.api.nvim_create_buf(true, false)
         vim.api.nvim_win_set_buf(win, new_buf)
      end)
   end
   if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd, "bdelete! " .. buf)
   end
end

M.skip_foldexpr = {}
local skip_check = assert(vim.uv.new_check())

function M.foldexpr()
   local buf = vim.api.nvim_get_current_buf()
   -- still in the same tick and no parser
   if M.skip_foldexpr[buf] then
      return "0"
   end

   -- don't use treesitter folds for non-file buffers
   if vim.bo[buf].buftype ~= "" then
      return "0"
   end

   -- as long as we don't have a filetype, don't bother
   -- checking if treesitter is available (it won't)
   if vim.bo[buf].filetype == "" then
      return "0"
   end

   local ok = pcall(vim.treesitter.get_parser, buf)
   if ok then
      return vim.treesitter.foldexpr()
   end

   M.skip_foldexpr[buf] = true
   skip_check:start(function()
      M.skip_foldexpr = {}
      skip_check:stop()
   end)
   return "0"
end

function M.get_kind_filter(buf)
   buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
   local ft = vim.bo[buf].filetype

   if M.icons.kind_filter == false then
      return
   end

   if M.icons.kind_filter[ft] == false then
      return
   end

   if type(M.icons.kind_filter[ft]) == "table" then
      return M.icons.kind_filter[ft]
   end

   return type(M.icons.kind_filter) == "table"
         and type(M.icons.kind_filter.default) == "table"
         and M.icons.kind_filter.default
      or nil
end

function M.spinner(interval)
   local spinner = M.icons.misc.spinner_frames
   local ms = (vim.uv or vim.loop).hrtime() / 1000000
   local frame = math.floor(ms / interval) % #spinner
   return spinner[frame + 1]
end

return M
