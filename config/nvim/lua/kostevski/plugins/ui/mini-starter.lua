local function create_header(text)
   local width = vim.o.columns
   local section_width = math.floor(width / 4)

   local total_pad = section_width - #text - 4
   local pad = string.rep("─", math.max(2, math.floor(total_pad / 2)))

   return string.format("%s %s %s", pad, text:upper(), pad)
end

local function format_item(name)
   -- Calculate proper indentation based on section width
   local indent = "  " -- 2 spaces for initial indent
   local icon = "  " -- Add space after icon for breathing room

   -- Special icons based on item type
   local icons = {
      --    ["Find File"] = " ", -- magnifying glass
      --    ["Recent"] = "󰋚 ", -- clock
      --    ["Config"] = " ", -- gear
      --    ["Lazy"] = "󰒲 ", -- package
      --    ["Mason"] = "󰏖 ", -- box
      --    ["Quit"] = " ", -- power
   }
   return indent .. (icons[name] or "░ ") .. name
end

local M = {
   sections = {},
}
-- M.sections.telescope = function()
--    return function()
--       return {
--          { action = "Telescope file_browser", name = "Browser", section = "Telescope" },
--          { action = "Telescope find_files", name = "Files", section = "Telescope" },
--          { action = "Telescope live_grep", name = "Live grep", section = "Telescope" },
--          { action = "Telescope oldfiles", name = "Old files", section = "Telescope" },
--       }
--    end
-- end

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
            local greeting = "Good "
               .. (hour < 12 and "morning" or hour < 18 and "afternoon" or "evening")
               .. ", "
               .. (os.getenv("USER") or "")
            return greeting
         end,
         items = {
            new_section("Find File", "Telescope find_files", "Files"),
            new_section("New File", "enew", "Built-in"),

            new_section("Recent", "Telescope oldfiles", "Files"),
            new_section("Grep", "Telescope live_grep", "Files"),
            new_section("Browse", "Telescope file_browser", "Files"),

            new_section("Nvim", "e $MYVIMRC", "Config"),
            new_section("Zsh", "e $ZDOTDIR", "Config"),
            new_section("Dotfiles", "e $DOTDIR", "Config"),

            new_section("Search", "Telescope projects", "Projects"),
            new_section("Todo", "TodoTelescope", "Projects"),
            -- new_section("Notes", "Neorg workspace notes", "Projects"),

            new_section("Last", "SessionLast", "Session"),

            new_section("Quit", "qa", "Built-in"),
         },
         footer = "",
         content_hooks = {
            starter.gen_hook.aligning("center", "center"),
            M.format_section,
         },
      }
      return config
   end,
}
