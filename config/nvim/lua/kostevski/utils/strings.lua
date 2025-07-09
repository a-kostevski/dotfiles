---@class UtilsStrings
---@field message fun(message: any, progress?: number): string? Format message for display
---@field title fun(title?: string, level?: integer, prefix?: string): string Format title for display
---@field truncate fun(text: string, max_length: integer): string
---@field sanitize fun(text: any): string
---@field code fun(text: string): string
---@field list fun(items: string[]): string
---@field split fun(str: string, delimiter?: string): string[]
---@field join fun(parts: string[], delimiter?: string): string
---@field pad fun(str: string, length: integer, char?: string, align?: "left"|"right"|"center"): string
---@field wrap fun(text: string, width: integer, indent?: integer): string
---@field starts_with fun(str: string, prefix: string): boolean
---@field ends_with fun(str: string, suffix: string): boolean
---@field trim fun(str: string): string
local Strings = {}

-- Constants
---@type integer
local MAX_TITLE_LENGTH = 50
---@type integer
local MAX_MESSAGE_SIZE = 1024
---@type string
local ELLIPSIS = "..."

---Truncate text to specified length, adding ellipsis if needed
---@param text string The text to truncate
---@param max_length integer Maximum length
---@return string truncated_text The truncated text
function Strings.truncate(text, max_length)
   if not text or #text <= max_length then
      return text or ""
   end
   return string.sub(text, 1, max_length - #ELLIPSIS) .. ELLIPSIS
end

---Sanitize text for display
---@param text any Text to sanitize
---@return string sanitized_text
function Strings.sanitize(text)
   if type(text) ~= "string" then
      text = tostring(text)
   end
   -- Convert tabs to spaces
   text = text:gsub("\t", "  ")
   -- Remove control characters except newlines
   text = text:gsub("[%c]", function(c)
      return c == "\n" and c or ""
   end)
   return text
end

---Format a message for display. Handles tables, sanitizes text, and truncates if needed.
---@param message any The message to format (string, table, or any type)
---@param progress? number Optional progress percentage (0-100)
---@return string? formatted_message The formatted message or nil if empty
function Strings.message(message, progress)
   if not message then
      return nil
   end

   -- Convert to string
   local text
   if type(message) == "table" then
      text = vim.islist(message) and table.concat(message, "\n") or vim.inspect(message)
   else
      text = tostring(message)
   end

   text = Strings.sanitize(text)
   if #text == 0 then
      return nil
   end

   -- Add progress if provided
   if progress then
      text = string.format("[%d%%] %s", progress, text)
   end

   -- Truncate if too long
   if #text > MAX_MESSAGE_SIZE then
      text = text:sub(1, MAX_MESSAGE_SIZE) .. ELLIPSIS
   end

   return text
end

---Format a title for display with optional level and prefix
---@param title? string The title to format
---@param level? integer Message level (vim.log.levels.ERROR/WARN/INFO/DEBUG/TRACE)
---@param prefix? string Optional prefix (e.g., LSP client name)
---@return string formatted_title The formatted title
function Strings.title(title, level, prefix)
   local parts = {}

   -- Add prefix if provided
   if prefix then
      table.insert(parts, Strings.sanitize(prefix))
   end

   -- Add title if provided
   if title then
      table.insert(parts, Strings.sanitize(title))
   end

   -- Join parts with separator
   local final_title = table.concat(parts, " - ")

   -- Add level indicator if provided
   if level then
      ---@type table<integer, string>
      local level_names = {
         [vim.log.levels.ERROR] = "ERROR",
         [vim.log.levels.WARN] = "WARN",
         [vim.log.levels.INFO] = "INFO",
         [vim.log.levels.DEBUG] = "DEBUG",
         [vim.log.levels.TRACE] = "TRACE",
      }
      local level_name = level_names[level] or "INFO"
      final_title = string.format("[%s] %s", level_name, final_title)
   end

   return Strings.truncate(final_title, MAX_TITLE_LENGTH)
end

---Format text as a markdown code block
---@param text string Text to format as code
---@return string formatted_code The text wrapped in code block markers
function Strings.code(text)
   return string.format("```\n%s\n```", Strings.sanitize(text))
end

---Format a list of items with bullet points
---@param items string[] List of items to format
---@return string formatted_list The formatted list as a single string
function Strings.list(items)
   local formatted = {}
   for _, item in ipairs(items) do
      table.insert(formatted, string.format("• %s", Strings.sanitize(item)))
   end
   return table.concat(formatted, "\n")
end

---Split a string by delimiter
---@param str string String to split
---@param delimiter? string Delimiter (default: "\n")
---@return string[] parts Array of split parts
function Strings.split(str, delimiter)
   delimiter = delimiter or "\n"
   local parts = {}
   local pattern = string.format("([^%s]+)", vim.pesc(delimiter))

   for part in str:gmatch(pattern) do
      table.insert(parts, part)
   end

   return parts
end

---Join strings with delimiter
---@param parts string[] Parts to join
---@param delimiter? string Delimiter (default: "\n")
---@return string joined The joined string
function Strings.join(parts, delimiter)
   delimiter = delimiter or "\n"
   return table.concat(parts, delimiter)
end

---Pad string to specified length
---@param str string String to pad
---@param length integer Target length
---@param char? string Padding character (default: " ")
---@param align? "left"|"right"|"center" Alignment (default: "left")
---@return string padded The padded string
function Strings.pad(str, length, char, align)
   char = char or " "
   align = align or "left"

   if #str >= length then
      return str
   end

   local padding = string.rep(char, length - #str)

   if align == "right" then
      return padding .. str
   elseif align == "center" then
      local left_pad = math.floor(#padding / 2)
      local right_pad = #padding - left_pad
      return string.rep(char, left_pad) .. str .. string.rep(char, right_pad)
   else
      return str .. padding
   end
end

---Wrap text to specified width, breaking at word boundaries
---@param text string Text to wrap
---@param width integer Maximum line width
---@param indent? integer Indent for wrapped lines (default: 0)
---@return string wrapped_text The wrapped text with newlines
function Strings.wrap(text, width, indent)
   indent = indent or 0
   local indent_str = string.rep(" ", indent)

   local lines = {}
   local current_line = ""

   for word in text:gmatch("%S+") do
      local test_line = current_line == "" and word or current_line .. " " .. word

      if #test_line > width then
         if current_line ~= "" then
            table.insert(lines, current_line)
            current_line = indent_str .. word
         else
            -- Word is longer than width, split it
            table.insert(lines, word)
            current_line = ""
         end
      else
         current_line = test_line
      end
   end

   if current_line ~= "" then
      table.insert(lines, current_line)
   end

   return table.concat(lines, "\n")
end

---Check if string starts with prefix
---@param str string String to check
---@param prefix string Prefix to look for
---@return boolean has_prefix True if string starts with prefix
function Strings.starts_with(str, prefix)
   return str:sub(1, #prefix) == prefix
end

---Check if string ends with suffix
---@param str string String to check
---@param suffix string Suffix to look for
---@return boolean has_suffix True if string ends with suffix
function Strings.ends_with(str, suffix)
   return #suffix == 0 or str:sub(-#suffix) == suffix
end

---Remove whitespace from both ends
---@param str string String to trim
---@return string trimmed The trimmed string
function Strings.trim(str)
   return str:match("^%s*(.-)%s*$")
end

return Strings
