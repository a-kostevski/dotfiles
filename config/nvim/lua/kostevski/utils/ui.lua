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

   -- no parser available, so mark it as skip
   -- in the next tick, all skip marks will be reset
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

return ui
