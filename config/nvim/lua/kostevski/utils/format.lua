local Format = setmetatable({}, {
   __call = function(m, ...)
      return m.format(...)
   end,
})

Format.formatters = {}

function Format.register(formatter)
   Format.formatters[#Format.formatters + 1] = formatter
   table.sort(Format.formatters, function(a, b)
      return a.priority > b.priority
   end)
end

function Format.formatexpr()
   return require("conform").formatexpr()
end

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

   Utils.notify[enabled and "info" or "warn"](table.concat(lines, "\n"))
end

function Format.toggle(buf)
   Format.enable(not Format.enabled(), buf)
end

function Format.enabled(buf)
   buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
   local gaf = vim.g.autoformat
   local baf = vim.b[buf].autoformat
   -- If the buffer has a local value, use that
   if baf ~= nil then
      return baf
   end

   return gaf == nil or gaf
end

function Format.enable(enable, buf)
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

function Format.format(opts)
   opts = opts or {}
   local buf = opts.buf or vim.api.nvim_get_current_buf()
   if not ((opts and opts.force) or Format.enabled(buf)) then
      return
   end

   local done = false
   for _, formatter in ipairs(Format.resolve(buf)) do
      if formatter.active then
         done = true
         local ok, format = pcall(formatter.format, buf)
         if ok then
            return format
         end
         Utils.notify.error("Formatter '" .. formatter.name .. "' failed")
      end
   end

   if not done and opts and opts.force then
      Utils.notify.warn("No formatter available")
   end
end

function Format.setup()
   -- Autoformat autocmd
   vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("Format", {}),
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
      Format.info()
   end, { desc = "Show info about the formatters for the current buffer" })
end

return Format
