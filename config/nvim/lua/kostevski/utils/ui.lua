local ui = {}

function ui.foldtext()
   local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
   local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext()
   if not ret or type(ret) == "string" then
      ret = { { vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1], {} } }
   end
   table.insert(ret, { " " .. require("config.icons").misc.dots })
   if not vim.treesitter.foldtext then
      return table.concat(
         vim.tbl_map(function(line)
            return line[1]
         end, ret),
         " "
      )
   end
   return ret
end

function ui.bufremove(buf)
   buf = buf or 0
   buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

   if vim.bo.modified then
      local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname()), "&Yes\n&No\n&Cancel")
      if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
         return
      end
      if choice == 1 then -- Yes
         vim.cmd.write()
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

ui.skip_foldexpr = {}
local skip_check = assert(vim.uv.new_check())

function ui.foldexpr()
   local buf = vim.api.nvim_get_current_buf()
   -- still in the same tick and no parser
   if ui.skip_foldexpr[buf] then
      return "0"
   end

   -- don't use treesitter folds for non-file buffers
   if vim.bo[buf].buftype ~= "" then
      return "0"
   end

   -- as long as we don't have a filetype, don't bother
   -- checking if treesitter is available (it won't)
   if vim.bo[buf].filetype == "" then
      return "0"
   end

   local ok = pcall(vim.treesitter.get_parser, buf)

   if ok then
      return vim.treesitter.foldexpr()
   end

   ui.skip_foldexpr[buf] = true
   skip_check:start(function()
      ui.skip_foldexpr = {}
      skip_check:stop()
   end)
   return "0"
end

ui.icons = require("kostevski.config.icons")

function ui.get_kind_filter(buf)
   buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
   local ft = vim.bo[buf].filetype

   if ui.icons.kind_filter == false then
      return
   end

   if ui.icons.kind_filter[ft] == false then
      return
   end

   if type(ui.icons.kind_filter[ft]) == "table" then
      return ui.icons.kind_filter[ft]
   end

   return type(ui.icons.kind_filter) == "table"
         and type(ui.icons.kind_filter.default) == "table"
         and ui.icons.kind_filter.default
      or nil
end

function ui.spinner(interval)
   local spinner = ui.icons.misc.spinner_frames
   local ms = (vim.uv or vim.loop).hrtime() / 1000000
   local frame = math.floor(ms / interval) % #spinner.frames
   return spinner.frames[frame + 1]
end

return ui
