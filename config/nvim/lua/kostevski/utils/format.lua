--- Format module provides functionality for registering and managing formatters.
--- It allows enabling/disabling autoformatting, resolving active formatters for a buffer,
--- and formatting buffers using registered formatters.
local Format = setmetatable({}, {
   __call = function(m, ...)
      return m.format(...)
   end,
})

Format.formatters = {}

--- Registers a new formatter.
--- @param formatter table: The formatter to register.
function Format.register(formatter)
   Format.formatters[#Format.formatters + 1] = formatter
   table.sort(Format.formatters, function(a, b)
      return a.priority > b.priority
   end)
end

-- Fix formatexpr return type annotation
---@return integer formatexpr The formatexpr value
function Format.formatexpr()
   return require("conform").formatexpr()
end

--- Resolves the active formatters for a buffer.
--- @param buf number: The buffer number (optional).
--- @return table: The resolved formatters.
function Format.resolve(buf)
   buf = buf or vim.api.nvim_get_current_buf()
   local have_primary = false
   return vim.tbl_map(function(formatter)
      local sources = formatter.sources(buf)
      local active = #sources > 0 and (not formatter.primary or not have_primary)
      have_primary = have_primary or (active and formatter.primary) or false
      return setmetatable({
         active = active,
         resolved = sources,
      }, { __index = formatter })
   end, Format.formatters)
end

--- Displays information about the formatters for a buffer.
--- @param buf number: The buffer number (optional).
function Format.info(buf)
   buf = buf or vim.api.nvim_get_current_buf()
   local gaf = vim.g.autoformat == nil or vim.g.autoformat
   local baf = vim.b[buf].autoformat
   local enabled = Format.enabled(buf)
   local lines = {
      "# Status",
      ("- [%s] global **%s**"):format(gaf and "x" or " ", gaf and "enabled" or "disabled"),
      ("- [%s] buffer **%s**"):format(
         enabled and "x" or " ",
         baf == nil and "inherit" or baf and "enabled" or "disabled"
      ),
   }
   local have = false
   for _, formatter in ipairs(Format.resolve(buf)) do
      if #formatter.resolved > 0 then
         have = true
         lines[#lines + 1] = "\n# " .. formatter.name .. (formatter.active and " ***(active)***" or "")
         for _, line in ipairs(formatter.resolved) do
            lines[#lines + 1] = ("- [%s] **%s**"):format(formatter.active and "x" or " ", line)
         end
      end
   end
   if not have then
      lines[#lines + 1] = "\n***No formatters available for this buffer.***"
   end

   if Utils.notify then
      Utils.notify[enabled and "info" or "warn"](table.concat(lines, "\n"))
   end
end

--- Toggles autoformatting for a buffer.
--- @param buf number: The buffer number (optional).
function Format.toggle(buf)
   Format.enable(buf, not Format.enabled(buf))
end

--- Checks if autoformatting is enabled for a buffer.
--- @param buf number: The buffer number (optional).
--- @return boolean: True if autoformatting is enabled, false otherwise.
function Format.enabled(buf)
   buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
   local g_autoformat = vim.g.autoformat
   local buf_autoformat = vim.b[buf].autoformat
   -- If the buffer has a local value, use that
   if buf_autoformat ~= nil then
      return buf_autoformat
   end

   return g_autoformat == nil or g_autoformat
end

--- Enables or disables autoformatting for a buffer.
--- @param enable boolean: True to enable, false to disable
--- @param buf number: The buffer number (optional).
function Format.enable(buf, enable)
   if enable == nil then
      enable = true
   end

   if buf then
      vim.b.autoformat = enable
   else
      vim.g.autoformat = enable
      vim.b.autoformat = nil
   end
end

--- Formats a buffer using the registered formatters.
--- @param opts table: Options for formatting (optional).
function Format.format(opts)
   opts = opts or {}
   local buf = opts.buf or vim.api.nvim_get_current_buf()

   if not ((opts and opts.force) or Format.enabled(buf)) then
      return
   end

   local formatted = false
   for _, formatter in ipairs(Format.resolve(buf)) do
      if formatter.active then
         formatted = true
         local ok, format = pcall(formatter.format, buf)
         if ok then
            return format
         end
         if Utils.notify then
            Utils.notify.error("Formatter '" .. formatter.name .. "' failed")
         end
      end
   end

   if not formatted and opts and opts.force then
      if Utils.notify then
         Utils.notify.warn("No formatter available")
      end
   end
end

--- Sets up the Format module, creating autocmds and user commands.
function Format.setup()
   local format_group = vim.api.nvim_create_augroup("Format", {})
   -- Autoformat autocmd
   vim.api.nvim_create_autocmd("BufWritePre", {
      group = format_group,
      callback = function(event)
         Format.format({ buf = event.buf })
      end,
   })

   -- Manual format
   vim.api.nvim_create_user_command("Format", function()
      Format.format({ force = true })
   end, { desc = "Format selection or buffer" })

   -- Format info
   vim.api.nvim_create_user_command("FormatInfo", function()
      Format.info(vim.api.nvim_get_current_buf())
   end, { desc = "Show info about the formatters for the current buffer" })
end

return Format
