-- Custom accent-bar render for nvim-notify
-- Renders notifications with a level-colored left accent bar and clean text layout
local ns = vim.api.nvim_create_namespace("notify-accent-render")

---@param bufnr integer
---@param notif table
---@param highlights table
---@param config table
local function accent_render(bufnr, notif, highlights, config)
   local accent = "▎"
   local pad = " "
   local prefix = accent .. pad

   local lines = {}
   local title_count = 0

   -- Title line (if present)
   local has_title = notif.title and notif.title[1] and #notif.title[1] > 0
   if has_title then
      table.insert(lines, prefix .. notif.title[1])
      title_count = 1
   end

   -- Message lines with accent prefix
   for _, line in ipairs(notif.message) do
      table.insert(lines, prefix .. line)
   end

   -- Ensure minimum width
   local min_width = type(config.minimum_width) == "function" and config.minimum_width() or (config.minimum_width or 30)
   for i, line in ipairs(lines) do
      local shortfall = min_width - vim.fn.strchars(line)
      if shortfall > 0 then
         lines[i] = line .. string.rep(" ", shortfall)
      end
   end

   vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

   -- Apply highlights
   for i = 0, #lines - 1 do
      -- Accent bar: colored by notification level
      vim.api.nvim_buf_set_extmark(bufnr, ns, i, 0, {
         hl_group = highlights.icon,
         end_col = #accent,
         priority = 50,
      })

      -- Text content
      local text_hl = (i < title_count) and highlights.title or highlights.body
      vim.api.nvim_buf_set_extmark(bufnr, ns, i, #prefix, {
         hl_group = text_hl,
         end_line = i + 1,
         priority = 50,
      })
   end

   -- Right-aligned secondary title (e.g. source/plugin name)
   if has_title and notif.title[2] and #notif.title[2] > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
         virt_text = { { notif.title[2] .. " ", highlights.title } },
         virt_text_pos = "right_align",
         priority = 50,
      })
   end
end

-- Link notification highlight groups to Diagnostic groups for colorscheme integration
local function setup_highlights()
   local links = {
      NotifyERRORBorder = "DiagnosticError",
      NotifyERRORTitle = "DiagnosticError",
      NotifyERRORIcon = "DiagnosticError",
      NotifyWARNBorder = "DiagnosticWarn",
      NotifyWARNTitle = "DiagnosticWarn",
      NotifyWARNIcon = "DiagnosticWarn",
      NotifyINFOBorder = "DiagnosticInfo",
      NotifyINFOTitle = "DiagnosticInfo",
      NotifyINFOIcon = "DiagnosticInfo",
      NotifyDEBUGBorder = "DiagnosticHint",
      NotifyDEBUGTitle = "DiagnosticHint",
      NotifyDEBUGIcon = "DiagnosticHint",
      NotifyTRACEBorder = "Comment",
      NotifyTRACETitle = "Comment",
      NotifyTRACEIcon = "Comment",
   }
   for group, link in pairs(links) do
      vim.api.nvim_set_hl(0, group, { link = link, default = true })
   end
end

return {
   {
      "rcarriga/nvim-notify",
      name = "notify",
      init = function()
         vim.notify = require("notify")
      end,
      keys = {
         {
            "<leader>nd",
            function()
               require("notify").dismiss({ silent = true, pending = true })
            end,
            desc = "Dismiss All Notifications",
         },
         {
            "<leader>nl",
            function()
               local history = require("notify").history()
               if #history == 0 then
                  return
               end
               local last = history[#history]
               require("notify").notify(last.message, last.level, {
                  title = last.title,
                  timeout = 5000,
               })
            end,
            desc = "Show Last Notification",
         },
         {
            "<leader>np",
            function()
               local notify = require("notify")
               local paused = not (vim.g.notifications_paused or false)
               vim.g.notifications_paused = paused
               if paused then
                  notify.dismiss({ silent = true, pending = true })
                  vim.notify("Notifications paused", vim.log.levels.WARN, {
                     timeout = 1500,
                     hide_from_history = true,
                  })
               else
                  vim.notify("Notifications resumed", vim.log.levels.INFO, {
                     timeout = 1500,
                     hide_from_history = true,
                  })
               end
            end,
            desc = "Pause/Resume Notifications",
         },
         {
            "<leader>nc",
            function()
               require("notify").dismiss({ silent = true, pending = true })
               -- Clear internal history by re-instantiating
               require("notify")._reset()
               vim.notify("Notification history cleared", vim.log.levels.INFO, {
                  timeout = 1500,
               })
            end,
            desc = "Clear Notification History",
         },
         {
            "<leader>no",
            function()
               local history = require("notify").history()
               if #history == 0 then
                  vim.notify("No notifications", vim.log.levels.INFO, { timeout = 1500 })
                  return
               end
               local last = history[#history]
               local lines = {}
               local title = last.title and table.concat(last.title, " - ") or ""
               if title ~= "" then
                  table.insert(lines, title)
                  table.insert(lines, string.rep("-", #title))
               end
               local msg = type(last.message) == "table" and last.message or vim.split(last.message, "\n")
               vim.list_extend(lines, msg)

               local buf = vim.api.nvim_create_buf(false, true)
               vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
               vim.bo[buf].modifiable = false
               vim.bo[buf].filetype = "markdown"
               vim.bo[buf].bufhidden = "wipe"

               local width = math.min(80, math.floor(vim.o.columns * 0.6))
               local height = math.min(#lines, math.floor(vim.o.lines * 0.5))
               local win = vim.api.nvim_open_win(buf, true, {
                  relative = "editor",
                  width = width,
                  height = height,
                  col = math.floor((vim.o.columns - width) / 2),
                  row = math.floor((vim.o.lines - height) / 2),
                  style = "minimal",
                  border = "rounded",
                  title = " Notification ",
                  title_pos = "center",
               })
               vim.keymap.set("n", "q", function()
                  vim.api.nvim_win_close(win, true)
               end, { buffer = buf })
            end,
            desc = "Open Last Notification in Buffer",
         },
         {
            "<leader>nf",
            function()
               vim.ui.select({ "ERROR", "WARN", "INFO", "DEBUG", "TRACE" }, {
                  prompt = "Filter notifications by level:",
               }, function(choice)
                  if not choice then
                     return
                  end
                  local level = vim.log.levels[choice]
                  local history = require("notify").history()
                  local filtered = vim.tbl_filter(function(notif)
                     return notif.level == level
                  end, history)

                  if #filtered == 0 then
                     vim.notify("No " .. choice:lower() .. " notifications", vim.log.levels.INFO, { timeout = 1500 })
                     return
                  end

                  local lines = {}
                  for _, notif in ipairs(filtered) do
                     local title = notif.title and table.concat(notif.title, " - ") or ""
                     local msg = type(notif.message) == "table" and table.concat(notif.message, " ") or notif.message
                     local entry = title ~= "" and (title .. ": " .. msg) or msg
                     table.insert(lines, entry)
                  end

                  local buf = vim.api.nvim_create_buf(false, true)
                  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                  vim.bo[buf].modifiable = false
                  vim.bo[buf].filetype = "markdown"
                  vim.bo[buf].bufhidden = "wipe"

                  local width = math.min(80, math.floor(vim.o.columns * 0.6))
                  local height = math.min(#lines, math.floor(vim.o.lines * 0.5))
                  local win = vim.api.nvim_open_win(buf, true, {
                     relative = "editor",
                     width = width,
                     height = height,
                     col = math.floor((vim.o.columns - width) / 2),
                     row = math.floor((vim.o.lines - height) / 2),
                     style = "minimal",
                     border = "rounded",
                     title = " " .. choice .. " Notifications ",
                     title_pos = "center",
                  })
                  vim.keymap.set("n", "q", function()
                     vim.api.nvim_win_close(win, true)
                  end, { buffer = buf })
               end)
            end,
            desc = "Filter Notifications by Level",
         },
         {
            "<leader>ns",
            function()
               require("telescope").extensions.notify.notify({})
            end,
            desc = "Search Notifications",
         },
      },
      opts = {
         timeout = 2500,
         max_width = function()
            return math.floor(vim.o.columns * 0.4)
         end,
         max_height = function()
            return math.floor(vim.o.lines * 0.3)
         end,
         minimum_width = 30,
         top_down = true,
         render = accent_render,
         stages = "fade_in_slide_out",
         fps = 60,
         icons = {
            ERROR = "",
            WARN = "",
            INFO = "",
            DEBUG = "",
            TRACE = "",
         },
         on_open = function(win)
            vim.wo[win].conceallevel = 3
            vim.wo[win].concealcursor = ""
            vim.wo[win].spell = false
            vim.wo[win].wrap = true
            vim.wo[win].linebreak = true
            local buf = vim.api.nvim_win_get_buf(win)
            vim.bo[buf].filetype = "markdown"
         end,
      },
      config = function(_, opts)
         setup_highlights()
         require("notify").setup(opts)
         -- Re-apply highlights on colorscheme change
         vim.api.nvim_create_autocmd("ColorScheme", {
            callback = setup_highlights,
         })
      end,
   },
   {
      "nvim-telescope/telescope.nvim",
      optional = true,
   },
}
