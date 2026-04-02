---@class LspProgress
local M = {}

---@type table<string, table> Active progress items by token
local progress_items = {}

---@type table<number, string> Client names cache
local client_names = {}

---@type boolean Whether to show notifications for progress events
local notify_enabled = false

---@type uv_timer_t|nil Statusline redraw timer
local redraw_timer = nil

---Enable or disable progress notifications
---@param enabled boolean
function M.set_notify(enabled)
  notify_enabled = enabled
end

---Process progress event data
---@param client_id integer LSP client ID
---@param token string|integer Progress token
---@param value table Progress value with kind, title, message, percentage
local function handle_progress(client_id, token, value)
  -- Get client name
  if not client_names[client_id] then
    local client = vim.lsp.get_client_by_id(client_id)
    client_names[client_id] = client and client.name or "LSP"
  end

  local key = string.format("%d:%s", client_id, token)

  if value.kind == "begin" then
    progress_items[key] = {
      client_id = client_id,
      client_name = client_names[client_id],
      token = token,
      title = value.title,
      message = value.message,
      percentage = value.percentage,
      start_time = vim.uv.now(),
    }
    M.on_begin(progress_items[key])
  elseif value.kind == "report" then
    local item = progress_items[key]
    if item then
      item.message = value.message or item.message
      item.percentage = value.percentage or item.percentage
      M.on_report(item)
    end
  elseif value.kind == "end" then
    local item = progress_items[key]
    if item then
      item.message = value.message or item.message
      item.end_time = vim.uv.now()
      M.on_end(item)
      progress_items[key] = nil
    end
  end

  -- Refresh statusline on progress changes
  local function refresh_statusline()
    local ok, lualine = pcall(require, "lualine")
    if ok then
      pcall(lualine.refresh)
    else
      pcall(vim.cmd.redrawstatus)
    end
  end

  if next(progress_items) then
    if not redraw_timer then
      redraw_timer = vim.uv.new_timer()
      redraw_timer:start(0, 120, vim.schedule_wrap(function()
        if not next(progress_items) then
          if redraw_timer then
            redraw_timer:stop()
            redraw_timer:close()
            redraw_timer = nil
          end
        end
        refresh_statusline()
      end))
    end
  elseif redraw_timer then
    redraw_timer:stop()
    redraw_timer:close()
    redraw_timer = nil
    vim.schedule(refresh_statusline)
  end

  -- Send to notify module if enabled
  if notify_enabled then
    local Utils = require("kostevski.utils")
    if Utils and Utils.notify and Utils.notify.progress then
      Utils.notify.progress({
        token = token,
        value = value,
      }, { client_id = client_id })
    end
  end
end

---Called when progress begins
---@param item table Progress item
function M.on_begin(item) end

---Called when progress is updated
---@param item table Progress item
function M.on_report(item) end

---Called when progress ends
---@param item table Progress item
function M.on_end(item) end

---Get active progress items
---@param client_id? number Optional client ID filter
---@return table[] items Active progress items
function M.get_active(client_id)
  local items = {}

  for _, item in pairs(progress_items) do
    if not client_id or item.client_id == client_id then
      table.insert(items, vim.deepcopy(item))
    end
  end

  table.sort(items, function(a, b)
    return a.start_time < b.start_time
  end)

  return items
end

---Format progress item for display
---@param item table Progress item
---@return string formatted Formatted progress string
function M.format(item)
  local parts = {}
  table.insert(parts, string.format("[%s]", item.client_name))
  if item.title then
    table.insert(parts, item.title)
  end
  if item.message then
    table.insert(parts, item.message)
  end
  if item.percentage then
    table.insert(parts, string.format("(%d%%)", item.percentage))
  end
  return table.concat(parts, " ")
end

---Get progress summary for statusline
---@return string summary Progress summary
function M.statusline()
  local items = M.get_active()

  if #items == 0 then
    return ""
  end

  local item = items[#items]
  local text = item.title or "Loading"

  if item.percentage then
    text = string.format("%s %d%%", text, item.percentage)
  end

  local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local ms = vim.uv.now() - item.start_time
  local frame = math.floor(ms / 120) % #spinner_frames + 1

  local result = string.format("%s %s", spinner_frames[frame], text)
  -- Escape % for statusline format strings
  return result:gsub("%%", "%%%%")
end

---Setup progress handling via LspProgress autocmd
function M.setup()
  vim.api.nvim_create_autocmd("LspProgress", {
    group = vim.api.nvim_create_augroup("kostevski_lsp_progress", { clear = true }),
    callback = function(ev)
      local data = ev.data
      if data and data.params then
        local value = data.params.value
        local token = data.params.token
        if value and token then
          handle_progress(data.client_id, token, value)
        end
      end
    end,
  })

  -- Clean up stale progress items periodically
  local timer = vim.uv.new_timer()
  timer:start(
    5000,
    5000,
    vim.schedule_wrap(function()
      local now = vim.uv.now()
      for key, item in pairs(progress_items) do
        if now - item.start_time > 30000 then
          progress_items[key] = nil
        end
      end
    end)
  )
end

---Show current progress items
function M.info()
  local items = M.get_active()

  if #items == 0 then
    vim.notify("No active LSP progress", vim.log.levels.INFO)
    return
  end

  local lines = { "# Active LSP Progress\n" }

  for _, item in ipairs(items) do
    table.insert(lines, M.format(item))
    local duration = vim.uv.now() - item.start_time
    table.insert(lines, string.format("  Duration: %.1fs", duration / 1000))
    table.insert(lines, "")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
