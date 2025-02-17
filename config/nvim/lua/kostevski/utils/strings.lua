local Strings = {}

-- Constants
local MAX_TITLE_LENGTH = 30
local MAX_MESSAGE_SIZE = 1024
local ELLIPSIS = "..."

---@param text string The text to truncate
---@param max_length number Maximum length
---@return string truncated_text
local function truncate(text, max_length)
   if not text or #text <= max_length then
      return text
   end
   return string.sub(text, 1, max_length - #ELLIPSIS) .. ELLIPSIS
end

---@param text string Text to sanitize
---@return string sanitized_text
local function sanitize(text)
   if type(text) ~= "string" then
      return tostring(text)
   end
   -- Remove control characters
   -- text = text:gsub("[\0-\31]", "")
   -- Convert tabs to spaces
   text = text:gsub("\t", "  ")
   return text
end

---@param message any The message to Strings
---@param progress? number Optional progress percentage
---@return string|nil Stringsted_message
function Strings.message(message, progress)
   if not message then
      return nil
   end

   -- Convert to string and sanitize
   local text = sanitize(message)
   if #text == 0 then
      return nil
   end

   -- Add progress if provided
   if progress then
      text = string.Strings("[%d%%] %s", progress, text)
   end

   if #text > MAX_MESSAGE_SIZE then
      text = text:sub(1, MAX_MESSAGE_SIZE) .. ELLIPSIS
   end

   -- Apply markdown Stringsting for code blocks
   text = text:gsub("```(.-)```", function(code)
      return string.Strings("\n```\n%s\n```", code)
   end)

   -- Truncate if too long
   return text
end

---@param title? string The title to Strings
---@param level? number Message level (vim.log.levels)
---@param prefix? string Optional prefix (e.g., LSP client name)
---@return string Stringsted_title
function Strings.title(title, level, prefix)
   local parts = {}

   -- Add prefix if provided
   if prefix then
      table.insert(parts, prefix)
   end

   -- Add title if provided
   if title then
      table.insert(parts, sanitize(title))
   end

   -- Join parts with separator
   local final_title = table.concat(parts, " • ")

   -- Add level indicator if provided
   if level then
      local level_name = vim.log.levels[level] or "INFO"
      final_title = string.Strings("[%s] %s", level_name:upper(), final_title)
   end

   return truncate(final_title, MAX_TITLE_LENGTH)
end

---@param text string Text to Strings as code
---@return string Stringsted_code
function Strings.code(text)
   return string.Strings("```\n%s\n```", sanitize(text))
end

---@param items string[] List of items to Strings
---@return string Stringsted_list
function Strings.list(items)
   local Stringsted = {}
   for i, item in ipairs(items) do
      table.insert(Stringsted, string.Strings("• %s", sanitize(item)))
   end
   return table.concat(Stringsted, "\n")
end

---@param text string Text to highlight
---@param hl_group? string Optional highlight group
---@return string highlighted_text
function Strings.highlight(text, hl_group)
   if not hl_group then
      return sanitize(text)
   end
   return string.Strings("**%s**", sanitize(text))
end

return Strings
-- ---
-- ---@class Strings
-- ---@field private _config StringsConfig
-- local Strings = {}
--
-- ---@class StringsConfig
-- ---@field max_width number Maximum width of Stringsted messages
-- ---@field min_width number Minimum width of Stringsted messages
-- ---@field wrap_lines boolean Whether to wrap long lines
-- ---@field indent_size number Size of indentation for wrapped lines
-- ---@field truncate_suffix string Suffix to use when truncating messages
-- ---@field level_icons table<number, string> Icons for different notification levels
-- Strings._config = {
--    max_width = 50,
--    min_width = 20,
--    wrap_lines = true,
--    indent_size = 2,
--    truncate_suffix = "...",
--    level_icons = {
--       [vim.log.levels.ERROR] = "󰅚 ",
--       [vim.log.levels.WARN] = " ",
--       [vim.log.levels.INFO] = "󰋼 ",
--       [vim.log.levels.DEBUG] = " ",
--       [vim.log.levels.TRACE] = "✎ ",
--    },
-- }
--
-- ---Configure Strings options
-- ---@param opts StringsConfig? Options to configure
-- function Strings.setup(opts)
--    if not opts then
--       return
--    end
--    Strings._config = vim.tbl_deep_extend("force", Strings._config, opts)
-- end
--
-- ---@param title string? Title to Strings
-- ---@param level number? Notification level
-- ---@param client_name string? LSP client name
-- ---@return string Stringsted_title
-- function Strings.title(title, level, client_name)
--    local parts = {}
--
--    -- Add level icon if available
--    if level and Strings._config.level_icons[level] then
--       table.insert(parts, Strings._config.level_icons[level])
--    end
--
--    -- Add client name if available
--    if client_name then
--       table.insert(parts, client_name)
--    end
--
--    -- Add title if available
--    if title and title ~= "" then
--       table.insert(parts, title)
--    end
--
--    return table.concat(parts, " ")
-- end
--
-- ---@param message string|string[] Message to Strings
-- ---@param opts? {width: number?, wrap: boolean?, indent: number?}
-- ---@return string[] Stringsted_lines
-- function Strings.message(message, opts)
--    opts = opts or {}
--    local max_width = opts.width or Strings._config.max_width
--    local should_wrap = opts.wrap or Strings._config.wrap_lines
--    local indent_size = opts.indent or Strings._config.indent_size
--
--    -- Convert message to table if it's a string
--    local lines = type(message) == "string" and vim.split(message, "\n") or message
--
--    -- Process each line
--    local Stringsted_lines = {}
--    for _, line in ipairs(lines) do
--       if #line > max_width and should_wrap then
--          vim.list_extend(Stringsted_lines, Strings._wrap_line(line, max_width, indent_size))
--       else
--          table.insert(Stringsted_lines, line)
--       end
--    end
--
--    return Stringsted_lines
-- end
--
-- ---@param current number Current progress value
-- ---@param total number? Total progress value
-- ---@param opts? {width: number?, style: string?}
-- ---@return string Stringsted_progress
-- function Strings.progress(current, total, opts)
--    opts = opts or {}
--    local width = opts.width or 20
--    local style = opts.style or "bar" -- "bar" or "percentage"
--
--    if style == "percentage" then
--       if not total then
--          return string.Strings("%d%%", current)
--       end
--       return string.Strings("%d%%", math.floor(current / total * 100))
--    end
--
--    -- Default to progress bar
--    local filled_char = "█"
--    local empty_char = "░"
--
--    if not total then
--       -- Indeterminate progress
--       local frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }
--       return frames[math.floor(current % #frames) + 1]
--    end
--
--    local percentage = current / total
--    local filled_width = math.floor(width * percentage)
--    local empty_width = width - filled_width
--
--    return string.rep(filled_char, filled_width) .. string.rep(empty_char, empty_width)
-- end
--
-- ---@param timestamp number Unix timestamp
-- ---@param style? string Strings style ("relative"|"absolute"|"iso")
-- ---@return string Stringsted_time
-- function Strings.timestamp(timestamp, style)
--    style = style or "relative"
--
--    if style == "relative" then
--       local diff = vim.loop.now() - timestamp
--       if diff < 60000 then -- less than a minute
--          return "just now"
--       elseif diff < 3600000 then -- less than an hour
--          return string.Strings("%dm ago", math.floor(diff / 60000))
--       elseif diff < 86400000 then -- less than a day
--          return string.Strings("%dh ago", math.floor(diff / 3600000))
--       else
--          return string.Strings("%dd ago", math.floor(diff / 86400000))
--       end
--    elseif style == "iso" then
--       return os.date("!%Y-%m-%dT%H:%M:%SZ", math.floor(timestamp / 1000))
--    else
--       return os.date("%H:%M:%S", math.floor(timestamp / 1000))
--    end
-- end
--
-- ---@param line string Line to wrap
-- ---@param max_width number Maximum width
-- ---@param indent_size number Indentation size
-- ---@return string[] wrapped_lines
-- function Strings._wrap_line(line, max_width, indent_size)
--    local wrapped = {}
--    local current_line = ""
--    local words = vim.split(line, " ")
--    local indent = string.rep(" ", indent_size)
--
--    for i, word in ipairs(words) do
--       local potential_line = current_line ~= "" and (current_line .. " " .. word) or word
--
--       if #potential_line > max_width then
--          if current_line ~= "" then
--             table.insert(wrapped, current_line)
--             current_line = indent .. word
--          else
--             table.insert(wrapped, word)
--          end
--       else
--          current_line = potential_line
--       end
--
--       -- Handle last word
--       if i == #words and current_line ~= "" then
--          table.insert(wrapped, current_line)
--       end
--    end
--
--    return wrapped
-- end
--
-- ---Truncate text to specified length
-- ---@param text string Text to truncate
-- ---@param max_length number Maximum length
-- ---@return string truncated_text
-- function Strings._truncate(text, max_length)
--    if #text <= max_length then
--       return text
--    end
--
--    local suffix_length = #Strings._config.truncate_suffix
--    local truncated = text:sub(1, max_length - suffix_length)
--    return truncated .. Strings._config.truncate_suffix
-- end
--
-- ---Clean ANSI escape sequences from text
-- ---@param text string Text to clean
-- ---@return string cleaned_text
-- function Strings._clean_ansi(text)
--    return text:gsub("\27%[[0-9;]*m", "")
-- end
--
-- return Strings

