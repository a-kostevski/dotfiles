local M = {}

-- Define modules outside the setup function
local modules = {
   { name = "options", requires = {} },
   { name = "autocmds", requires = {} },
   { name = "keymaps", requires = { "options" } },
   { name = "lazy", requires = { "options" } },
}

function M.setup()
   local Utils = require("kostevski.utils")
   Utils.setup()
   _G.Utils = Utils

   -- Load modules in dependency order
   require("kostevski.config.options")
   require("kostevski.config.autocmds")
   require("kostevski.config.keymaps")
   require("kostevski.config.lazy").setup()
   Utils.toggle.setup()
end

return M
