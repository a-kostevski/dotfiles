-- A logical OR of `line_begin` and the regTrig '[^%a]trig'
local function line_begin_or_non_letter(line_to_cursor, matched_trigger)
   local line_begin = line_to_cursor:sub(1, -(#matched_trigger + 1)):match("^%s*$")
   local non_letter = line_to_cursor:sub(-(#matched_trigger + 1), -(#matched_trigger + 1)):match('[ :`=%{%(%["]')
   return line_begin or non_letter
end

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local d = ls.dynamic_node
local fmta = require("luasnip.extras.fmt").fmta
local f = ls.function_node
local i = ls.insert_node

local get_visual = function(args, parent)
   if #parent.snippet.env.LS_SELECT_RAW > 0 then
      return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
   else
      return sn(nil, i(1, ""))
   end
end

return {
   -- Paired parentheses
   s({ trig = "(", wordTrig = false, snippetType = "autosnippet" }, {
      t("("),
      d(1, get_visual),
      t(")"),
   }),
   -- Paired curly braces
   s({ trig = "{", wordTrig = false, snippetType = "autosnippet" }, {
      t("{"),
      d(1, get_visual),
      t("}"),
   }),
   -- Paired square brackets
   s({ trig = "[", wordTrig = false, snippetType = "autosnippet" }, {
      t("["),
      d(1, get_visual),
      t("]"),
   }),
   -- Paired back ticks
   s({ trig = "sd", snippetType = "autosnippet" }, {
      f(function(_, snip)
         return snip.captures[1]
      end),
      t("`"),
      d(1, get_visual),
      t("`"),
   }),
   -- Paired double quotes
   s(
      { trig = '"', wordTrig = false, snippetType = "autosnippet", priority = 2000 },
      fmta('"<>"', {
         d(1, get_visual),
      }),
      { condition = line_begin_or_non_letter }
   ),
   -- Paired single quotes
   s(
      { trig = "'", wordTrig = false, snippetType = "autosnippet", priority = 2000 },
      fmta("'<>'", {
         d(1, get_visual),
      }),
      { condition = line_begin_or_non_letter }
   ),
   -- Curly braces
   s(
      { trig = "fds", snippetType = "autosnippet" },
      fmta(
         [[
        {
          <>
        }
        ]],
         { d(1, get_visual) }
      )
   ),
   -- Square braces
   s(
      { trig = "gds", snippetType = "autosnippet" },
      fmta(
         [[
        [
          <>
        ]
        ]],
         { d(1, get_visual) }
      )
   ),
   -- em dash
   s({ trig = "---", wordTrig = false }, { t("—") }),
   -- Lorem ipsum
   s(
      { trig = "lipsum" },
      fmta(
         [[
        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
        ]],
         {}
      )
   ),
   -- d.o.o.
   s({ trig = "doo" }, { t("d.o.o.") }),
}
