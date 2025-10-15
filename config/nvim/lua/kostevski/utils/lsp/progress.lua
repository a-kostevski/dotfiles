---@class LspProgress
local M = {}

---@type table<string, table> Active progress items by token
local progress_items = {}

---@type table<number, string> Client names cache
local client_names = {}

---Progress handler
---@param _ any Error (unused)
---@param result table Progress result
---@param ctx table Context with client_id
function M.handler(_, result, ctx)
  local client_id = ctx.client_id
  local token = result.token

  -- Get client name
  if not client_names[client_id] then
    local client = vim.lsp.get_client_by_id(client_id)
    client_names[client_id] = client and client.name or "LSP"
  end

  local key = string.format("%d:%s", client_id, token)

  -- Handle different progress kinds
  local value = result.value
  if value.kind == "begin" then
    progress_items[key] = {
      client_id = client_id,
      client_name = client_names[client_id],
      token = token,
      title = value.title,
      message = value.message,
      percentage = value.percentage,
      start_time = vim.loop.now(),
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
      item.end_time = vim.loop.now()
      M.on_end(item)
      progress_items[key] = nil
    end
  end
end

---Called when progress begins
---@param item table Progress item
function M.on_begin(item)
  -- Override this function to handle progress start
  -- Default: do nothing (let notify module handle it)
end

---Called when progress is updated
---@param item table Progress item
function M.on_report(item)
  -- Override this function to handle progress updates
  -- Default: do nothing (let notify module handle it)
end

---Called when progress ends
---@param item table Progress item
function M.on_end(item)
  -- Override this function to handle progress end
  -- Default: do nothing (let notify module handle it)
end

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

  -- Sort by start time
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

  -- Add client name
  table.insert(parts, string.format("[%s]", item.client_name))

  -- Add title
  if item.title then
    table.insert(parts, item.title)
  end

  -- Add message
  if item.message then
    table.insert(parts, item.message)
  end

  -- Add percentage
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

  -- Show the most recent item
  local item = items[#items]
  local text = item.title or "Loading"

  if item.percentage then
    text = string.format("%s %d%%", text, item.percentage)
  end

  -- Add spinner
  local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }
  local ms = vim.loop.now() - item.start_time
  local frame = math.floor(ms / 120) % #spinner_frames + 1

  return string.format("%s %s", spinner_frames[frame], text)
end

---Setup progress handling
function M.setup()
  -- Replace default progress handler with silent version
  vim.lsp.handlers["$/progress"] = function(_, result, ctx)
    -- Store progress internally but don't notify
    M.handler(_, result, ctx)
  end

  -- Clean up stale progress items periodically
  local timer = vim.loop.new_timer()
  timer:start(
    5000,
    5000,
    vim.schedule_wrap(function()
      local now = vim.loop.now()
      for key, item in pairs(progress_items) do
        -- Remove items older than 30 seconds without an end
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

    local duration = vim.loop.now() - item.start_time
    table.insert(lines, string.format("  Duration: %.1fs", duration / 1000))
    table.insert(lines, "")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
