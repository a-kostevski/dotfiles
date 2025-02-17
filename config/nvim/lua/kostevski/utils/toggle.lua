local toggle = setmetatable({}, {
   __index = function(toggle, ...)
      return toggle(...)
   end,
})
local function notify_toggle(feature, state)
   local message = feature .. (state and " enabled" or " disabled")
   Utils.notify.info(message, { title = "Toggle" })
end

---@class ToggleOptions
---@field name string
---@field get function
---@field set function
---@field desc? string
---@field keymap? string

---@param opts ToggleOptions
local function create_toggle(opts)
   local desc = opts.desc or opts.name or ""
   local t = {
      name = opts.name,
      get = opts.get,
      set = function(state)
         opts.set(state)
         notify_toggle(desc, state)
      end,
      toggle = function()
         local state = not opts.get()
         opts.set(state)
         notify_toggle(desc, state)
      end,
   }

   if opts.keymap then
      vim.keymap.set("n", opts.keymap, function()
         t.toggle()
      end, {
         desc = desc,
         silent = true,
      })
   end

   return t
end

function toggle.create(opts)
   if not opts.get or type(opts.get) ~= "function" then
      Utils.notify.error("Invalid toggle: 'get' and 'set' must be functions")
      return nil
   elseif not opts.set or type(opts.set) ~= "function" then
      Utils.notify.error("Invalid toggle: 'get' and 'set' must be functions")
      return nil
   end
   if not opts.name then
      Utils.notify.error("toggle must have a name")
      return nil
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

function toggle.setup()
   -- Define standard toggles
   toggle.create({
      name = "inline_hint",
      get = function()
         return vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
      end,
      set = function(state)
         vim.lsp.inlay_hint.enable(state, { bufnr = 0 })
      end,
      keymap = "<leader>th",
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
      keymap = "<leader>tl",
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
      keymap = "<leader>ti",
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
      keymap = "<leader>tm",
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
      keymap = "<leader>tw",
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
      keymap = "<leader>tx",
      desc = "Syntax highlighting",
   })

   toggle.create({
      name = "diagnostics",
      get = function()
         return vim.diagnostic.is_enabled()
      end,
      set = function(state)
         vim.diagnostic.enable(state)
      end,
      keymap = "<leader>td",
      desc = "Vim diagnostics",
   })

   toggle.create({
      name = "noneckpain",
      get = function()
         return true
      end,
      set = function(_)
         vim.cmd(":NoNeckPain")
      end,
      keymap = "<leader>tn",
      desc = "No Neck Pain",
   })

   toggle.create({
      name = "signature_help",
      get = function()
         return vim.b.signature_help_enabled or false
      end,
      set = function(state)
         vim.b.signature_help_enabled = state

         if state then
            vim.api.nvim_create_autocmd("CursorHoldI", {
               buffer = 0,
               callback = function()
                  if vim.b.signature_help_enabled and #Utils.lsp.get_clients({ bufnr = 0 }) > 0 then
                     vim.lsp.buf.signature_help()
                  end
               end,
               desc = "Show signature help",
            })
         else
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds({
               buffer = 0,
               event = "CursorHoldI",
            })
         end
      end,
      keymap = "<leader>ts",
      desc = "Signature help",
   })

   toggle.create({
      name = "mouse",
      get = function()
         return vim.opt.mouse:get() ~= ""
      end,
      set = function(state)
         vim.opt.mouse = state and "a" or ""
      end,
      keymap = "<leader>tM",
      desc = "Mouse support",
   })
end

return toggle
