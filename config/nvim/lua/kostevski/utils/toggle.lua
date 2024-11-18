local toggle = {}

local function notify_toggle(feature, state)
   local message = feature .. (state and " enabled" or " disabled")
   Utils.notify.info(message)
end

local function create_toggle(opts)
   local name = opts.name
   local get = opts.get
   local set = opts.set
   local desc = opts.desc or name or ""
   local keymap = opts.keymap

   if type(get) ~= "function" or type(set) ~= "function" then
      Utils.notify.error("Invalid toggle: 'get' and 'set' must be functions")
   end

   local t = {
      name = name,
      get = get,
      set = function(state)
         set(state)
         notify_toggle(desc, state)
      end,
      toggle = function()
         local state = not get()
         set(state)
         notify_toggle(desc, state)
      end,
   }

   if keymap then
      vim.api.nvim_set_keymap("n", keymap, "", {
         desc = desc,
         noremap = true,
         silent = true,
         callback = function()
            t.toggle()
         end,
      })
   end

   return t
end

function toggle.create(opts)
   if not opts.name then
      Utils.notify.error("toggle must have a name")
   end
   toggle[opts.name] = create_toggle(opts)
end

function toggle.get(name)
   if toggle[name] and toggle[name].get then
      return toggle[name].get()
   else
      Utils.notify.error("Toggle '" .. name .. "' does not exist or has no 'get' method")
   end
end

-- Define standard toggles
toggle.create({
   name = "inline_hint",
   get = vim.lsp.inlay_hint.is_enabled,
   set = vim.lsp.inlay_hint.enable,
   keymap = "<leader>uh",
   desc = "Inline hints",
})

toggle.create({
   name = "relative_lineno",
   get = function()
      return vim.opt_local.relativenumber:get()
   end,
   set = function(state)
      vim.opt_local.relativenumber = state
   end,
   keymap = "<leader>ul",
   desc = "Relative line numbers",
})

toggle.create({
   name = "indent_guides",
   get = function()
      return require("ibl.config").get_config(0).enabled
   end,
   set = function(state)
      require("ibl").setup_buffer(0, { enabled = state })
   end,
   keymap = "<leader>ui",
   desc = "Indent guides",
})

toggle.create({
   name = "spell_check",
   get = function()
      return vim.opt_local.spell:get()
   end,
   set = function(state)
      vim.opt_local.spell = state
   end,
   keymap = "<leader>us",
   desc = "Spell check",
})

toggle.create({
   name = "line_wrap",
   get = function()
      return vim.opt_local.wrap:get()
   end,
   set = function(state)
      vim.opt_local.wrap = state
   end,
   keymap = "<leader>uw",
   desc = "Line wrap",
})

toggle.create({
   name = "syntax_highlighting",
   get = function()
      return vim.opt_local.syntax == "on"
   end,
   set = function(state)
      vim.opt_local.syntax = state and "on" or "off"
   end,
   keymap = "<leader>ux",
   desc = "Syntax highlighting",
})

toggle.create({
   name = "diagnostics",
   get = vim.diagnostic.is_enabled,
   set = function(state)
      vim.diagnostic.enable(state)
   end,
   keymap = "<leader>ud",
   desc = "Vim diagnostics",
})

return toggle
