local notify = {}

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
      title = opts.title or "Nvim",
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

local client_notifs = {}

local function get_notif_data(client_id, token)
   client_notifs[client_id] = client_notifs[client_id] or {}
   client_notifs[client_id][token] = client_notifs[client_id][token] or {}
   return client_notifs[client_id][token]
end

local function update_spinner(client_id, token)
   local notif_data = get_notif_data(client_id, token)
   local spinner_frames = Utils.ui.icons.misc.spinner_frames
   if notif_data.spinner then
      local new_spinner = (notif_data.spinner + 1) % #spinner_frames
      notif_data.spinner = new_spinner

      notif_data.notification = vim.notify(nil, nil, {
         hide_from_history = true,
         icon = spinner_frames[new_spinner],
         replace = notif_data.notification,
      })

      vim.defer_fn(function()
         update_spinner(client_id, token)
      end, 100)
   end
end

local function format_title(title, client_name)
   return client_name .. (#title > 0 and ": " .. title or "")
end

local function format_message(message, percentage)
   return (percentage and percentage .. "%\t" or "") .. (message or "")
end

-- LSP integration
vim.lsp.handlers["$/progress"] = function(_, result, ctx)
   local client_id = ctx.client_id

   local val = result.value

   if not val.kind then
      return
   end

   local notif_data = get_notif_data(client_id, result.token)

   if val.kind == "begin" then
      local message = format_message(val.message, val.percentage)
      local spinner_frames = Utils.ui.icons.misc.spinner_frames
      notif_data.notification = vim.notify(message, vim.log.levels.INFO, {
         title = format_title(val.title, vim.lsp.get_client_by_id(client_id).name),
         icon = spinner_frames[1],
         timeout = false,
         hide_from_history = false,
      })
      notif_data.spinner = 1
      update_spinner(client_id, result.token)
   elseif val.kind == "report" and notif_data then
      notif_data.notification = vim.notify(format_message(val.message, val.percentage), vim.log.levels.INFO, {
         replace = notif_data.notification,
         hide_from_history = false,
      })
   elseif val.kind == "end" and notif_data then
      notif_data.notification =
         vim.notify(val.message and format_message(val.message) or "Complete", vim.log.levels.INFO, {
            icon = "",
            replace = notif_data.notification,
            timeout = 3000,
         })
      notif_data.spinner = nil
   end
end

-- table from lsp severity to vim severity.
local severity = {
   "error",
   "warn",
   "info",
   "hint",
}
vim.lsp.handlers["window/showMessage"] = function(err, method, params, client_id)
   vim.notify(method.message, severity[params.type])
end

return notify
