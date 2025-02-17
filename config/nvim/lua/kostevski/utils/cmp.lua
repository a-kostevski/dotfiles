local completion = {}

completion.actions = {
   snippet_forward = function()
      if vim.snippet.active({ direction = 1 }) then
         vim.schedule(function()
            vim.snippet.jump(1)
         end)
         return true
      end
   end,
}
function completion.snippet_replace(snippet, fn)
   return snippet:gsub("%$%b{}", function(m)
      local n, name = m:match("^%${(%d+):(.+)}$")
      return n and fn({ n = n, text = name }) or m
   end) or snippet
end

function completion.snippet_preview(snippet)
   local ok, parsed = pcall(function()
      return vim.lsp._snippet_gramar.parse(snippet)
   end)
   return ok and tostring(parsed)
      or completion
         .snippet_replace(snippet, function(placeholder)
            return completion.snippet_preview(placeholder.text)
         end)
         :gsub("%$0", "")
end

function completion.snippet_fix(snippet)
   local texts = {}
   return completion.snippet_replace(snippet, function(placeholder)
      texts[placeholder.n] = texts[placeholder.n] or completion.snippet_preview(placeholder.text)
      return "${" .. placeholder.n .. ":" .. texts[placeholder.n] .. "}"
   end)
end

function completion.has_words_before_cursor()
   local line = vim.api.nvim_get_current_line()
   local cursor = vim.api.nvim_win_get_cursor(0)
   return vim.fn.matchstr(line:sub(1, cursor[2]), [[\k*$]]) ~= ""
end


function completion.insert_source(opts, src, index)
   opts.sources = opts.sources or {}
   table.insert(opts.sources, index or #opts.sources + 1, src)
end

function completion.visible()
   local blink = require("blink.cmp")
   return blink.windows and blink.windows.autocomplete.win:is_open()
end

-- function completion.confirm(opts)
--    local cmp = require("cmp")
--    local luasnip = require("luasnip")
--    opts = vim.tbl_extend("force", {
--       select = true,
--       behavior = cmp.ConfirmBehavior.Insert,
--    }, opts or {})
--    return cmp.mapping(function(fallback)
--       if cmp.visible() then
--          if luasnip.expandable() then
--             luasnip.expand()
--          else
--             cmp.confirm({
--                select = true,
--             })
--          end
--       else
--          fallback()
--       end
--    end)

-- return function
-- return function(fallback)
--    if cmp.core.view:visible() or vim.fn.pumvisible() == 1 then
--       if vim.api.nvim_get_mode().mode == "i" then
--          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-G>u", true, true, true), "n", false):w
--
--       end
--       if cmp.confirm(opts) then
--          return
--       end
--    end
--    return fallback()
-- end
-- end

-- function completion.expand(snippet)
--    local session = vim.snippet.active() and vim.snippet._session or nil
--
--    local ok, err = pcall(vim.snippet.expand, snippet)
--    if not ok then
--       local fixed = completion.snippet_fix(snippet)
--       ok = pcall(vim.snippet.expand, fixed)
--
--       local msg = ok and "Failed to parse snippet,\nbut was able to fix it automatically."
--          or ("Failed to parse snippet.\n" .. err)
--
--       Utils[ok and "warn" or "error"](
--          ([[%s
-- ```%s
-- %s
-- ```]]):format(msg, vim.bo.filetype, snippet),
--          { title = "vim.snippet" }
--       )
--    end
--
--    -- Restore top-level session when needed
--    if session then
--       vim.snippet._session = session
--    end
-- end
--
return completion
