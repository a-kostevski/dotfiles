local function create_header(text)
   local width = vim.o.columns
   local section_width = math.floor(width / 4)

   local total_pad = section_width - #text - 4
   local pad = string.rep("─", math.max(2, math.floor(total_pad / 2)))

   return string.format("%s %s %s", pad, text:upper(), pad)
end

local M = {
   sections = {},
}

function M.format_section(content, _)
   local current_section = ""
   local coords = MiniStarter.content_coords(content, "item")
   for _, c in ipairs(coords) do
      local unit = content[c.line][c.unit]
      local item = unit.item
   end
   return content
end

return {
   "echasnovski/mini.starter",
   event = "VimEnter",
   opts = function()
      local pad = string.rep("-", 22)
      local new_section = function(name, action, section)
         return { name = name, action = action, section = create_header(section) }
      end
      local starter = require("mini.starter")
      local config = {
         evaluate_single = true,
         header = function()
            local hour = tonumber(os.date("%H"))
            local greetings = {
               [1] = "  Sleep well", -- 1-6
               [2] = "  Good morning", -- 6-12
               [3] = "  Good afternoon", -- 12-18
               [4] = "  Good evening", -- 18-24
            }
            local greeting_idx = math.floor((hour + 6) / 6)
            if greeting_idx == 0 then
               greeting_idx = 4
            end

            local greeting = greetings[greeting_idx] .. ", " .. (os.getenv("USER") or "")
            local datetime = os.date("   %A, %d %B")

            -- Center the header text
            local width = vim.o.columns
            local function center(str)
               local padding = math.floor((width - #str) / 2)
               return string.rep(" ", padding) .. str
            end
            return string.format("%s\n%s", greeting, datetime)
         end,
         items = {
            new_section("Find File", "Telescope find_files", "Files"),
            new_section("New File", "enew", "Built-in"),

            new_section("Recent", "Telescope oldfiles", "Files"),
            new_section("Grep", "Telescope live_grep", "Files"),
            new_section("Browse", "Telescope file_browser", "Files"),

            new_section("Vim", "e $MYVIMRC", "Config"),
            new_section("Zsh", "e $ZDOTDIR", "Config"),
            new_section("Dotfiles", "e $DOTDIR", "Config"),

            new_section("Projects", "Telescope projects", "Projects"),
            new_section("Todo", "TodoTelescope", "Projects"),

            new_section("Last session", [[lua require("persistence").load()]], "Session"),
            new_section("Quit", "qa", "Built-in"),
         },
         footer = "",
         content_hooks = {
            starter.gen_hook.adding_bullet("░ ", false),
            starter.gen_hook.aligning("center", "center"),
            M.format_section,
         },
      }
      return config
   end,
}
