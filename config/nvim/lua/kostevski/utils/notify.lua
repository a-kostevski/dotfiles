local notify = {}

function notify.pretty_trace(opts)
   opts = opts or {}
   local Config = require("lazy.core.config")
   local trace = {}
   local level = opts.level or 2
   while true do
      local info = debug.getinfo(level, "Sln")
      if not info then
         break
      end
      if info.what ~= "C" and (Config.options.debug or not info.source:find("lazy.nvim")) then
         local source = info.source:sub(2)
         if source:find(Config.options.root, 1, true) == 1 then
            source = source:sub(#Config.options.root + 1)
         end
         source = vim.fn.fnamemodify(source, ":p:~:.") --[[@as string]]
         local line = "  - " .. source .. ":" .. info.currentline
         if info.name then
            line = line .. " _in_ **" .. info.name .. "**"
         end
         table.insert(trace, line)
      end
      level = level + 1
   end
   return #trace > 0 and ("\n\n# stacktrace:\n" .. table.concat(trace, "\n")) or ""
end
function notify.notify(msg, opts)
   if vim.in_fast_event() then
      return vim.schedule(function()
         notify.notify(msg, opts)
      end)
   end
   opts = opts or {}
   if type(msg) == "table" then
      msg = table.concat(
         vim.tbl_filter(function(line)
            return line or false
         end, msg),
         "\n"
      )
   end
   if opts.stacktrace then
      msg = msg .. notify.pretty_trace({ level = opts.stacklevel or 2 })
   end
   local lang = opts.lang or "markdown"
   local n = opts.once and vim.notify_once or vim.notify
   n(msg, opts.level or vim.log.levels.INFO, {
      on_open = function(win)
         local ok = pcall(function()
            vim.treesitter.language.add("markdown")
         end)
         if not ok then
            pcall(require, "nvim-treesitter")
         end
         vim.wo[win].conceallevel = 3
         vim.wo[win].concealcursor = ""
         vim.wo[win].spell = false
         local buf = vim.api.nvim_win_get_buf(win)
         if not pcall(vim.treesitter.start, buf, lang) then
            vim.bo[buf].filetype = lang
            vim.bo[buf].syntax = lang
         end
      end,
      title = opts.title or "lazy.nvim",
   })
end
function notify.error(message, opts)
   opts = opts or {}
   opts.level = vim.log.levels.ERROR
   notify.notify(message, opts)
end
function notify.warn(message, opts)
   opts = opts or {}
   opts.level = vim.log.levels.WARN
   notify.notify(message, opts)
end
function notify.info(message, opts)
   opts = opts or {}
   opts.level = vim.log.levels.INFO
   notify.notify(message, opts)
end
return notify
