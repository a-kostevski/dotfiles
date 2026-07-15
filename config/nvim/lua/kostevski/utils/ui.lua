local M = {}

local icons = {
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
    Color = " ",
    Control = " ",
    Collapsed = " ",
    Constant = "󰏿 ",
    Constructor = " ",
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
}

M.icons = icons

function M.bufremove(buf)
  buf = buf or 0
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

  if vim.bo[buf].modified then
    local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname(buf)), "&Yes\n&No\n&Cancel")
    if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
      return
    end
    if choice == 1 then -- Yes
      vim.api.nvim_buf_call(buf, function()
        vim.cmd.write()
      end)
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

return M
