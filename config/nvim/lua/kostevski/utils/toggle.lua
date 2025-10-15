-- ============================================================================
-- Toggle Utilities - Feature toggle system with keybindings
-- ============================================================================
-- This module provides a framework for creating feature toggles with:
--   - Automatic state management
--   - Optional keybinding registration
--   - User notifications on state changes
--   - Error handling and validation
--
-- Built-in toggles:
--   - Inlay hints, relative line numbers, indent guides
--   - Spell check, line wrap, syntax highlighting
--   - Diagnostics, formatting, signature help
--   - Mouse support, conceal, treesitter
--
-- Usage:
--   local Toggle = require("kostevski.utils.toggle")
--   Toggle.create({
--     name = "my_feature",
--     get = function() return vim.g.my_feature end,
--     set = function(state) vim.g.my_feature = state end,
--     keymap = "<leader>tf",
--   })
-- ============================================================================

---@class Toggle Feature toggle management system
---@field [string] {get: function, set: function, toggle: function} Individual toggle instances
local toggle = setmetatable({}, {
  __index = function(t, k)
    return t[k]
  end,
})

---Send toggle notification
---@param feature string Feature name
---@param state boolean Feature state
local function notify_toggle(feature, state)
  local Utils = require("kostevski.utils")
  local message = feature .. (state and " enabled" or " disabled")
  if Utils.notify then
    Utils.notify.info(message, { title = "Toggle" })
  end
end

---@class ToggleOptions Toggle creation options
---@field name string Unique toggle identifier (used as table key)
---@field get function Function that returns the current state (boolean)
---@field set function Function that sets a new state (receives boolean parameter)
---@field desc? string Human-readable description (shown in notifications and keybindings)
---@field keymap? string Optional keymap (e.g., "<leader>th" for inlay hints)

---Create a toggle instance with validation and error handling
---
---Internal function that creates a toggle object with get, set, and toggle methods.
---Validates all required options and sets up automatic notifications.
---
---@param opts ToggleOptions Configuration for the toggle
---@return table? toggle_instance The created toggle, or nil if validation fails
local function create_toggle(opts)
  -- Validate options
  local Utils = require("kostevski.utils")

  -- Basic validation if errors module isn't loaded yet
  if not opts.name or type(opts.name) ~= "string" then
    if Utils.notify then
      Utils.notify.error("Invalid toggle options: name must be a string")
    end
    return nil
  end
  if not opts.get or type(opts.get) ~= "function" then
    if Utils.notify then
      Utils.notify.error("Invalid toggle options: get must be a function")
    end
    return nil
  end
  if not opts.set or type(opts.set) ~= "function" then
    if Utils.notify then
      Utils.notify.error("Invalid toggle options: set must be a function")
    end
    return nil
  end

  local desc = opts.desc or opts.name or ""
  local instance = {
    name = opts.name,
    get = opts.get,
  }
  instance.set = function(state)
    local ok, err = pcall(opts.set, state)
    if ok then
      notify_toggle(desc, state)
    elseif Utils.notify then
      Utils.notify.error(string.format("Toggle '%s' set error: %s", opts.name, err))
    end
  end
  instance.toggle = function()
    local current = instance.get()
    if current ~= nil then
      local new_state = not current
      instance.set(new_state)
    end
  end

  if opts.keymap then
    vim.keymap.set("n", opts.keymap, instance.toggle, {
      desc = desc,
      silent = true,
    })
  end

  return instance
end

---Create and register a new toggle in the toggle system
---
---This is the main API for creating toggles. Creates a toggle instance
---and registers it in the toggle table for later access.
---
---@param opts ToggleOptions Toggle configuration
---
---@usage
---  toggle.create({
---    name = "my_feature",
---    get = function() return vim.g.my_feature end,
---    set = function(state) vim.g.my_feature = state end,
---    desc = "My custom feature",
---    keymap = "<leader>tm",
---  })
---  -- Later access: toggle.my_feature.toggle()
function toggle.create(opts)
  local t = create_toggle(opts)
  if t then
    toggle[opts.name] = t
  end
end

---Get the current state of a registered toggle
---
---@param name string The toggle identifier (e.g., "inlay_hints")
---@return boolean? state The current toggle state, or nil if toggle doesn't exist
---
---@usage
---  local enabled = toggle.get("inlay_hints")
function toggle.get(name)
  if toggle[name] and toggle[name].get then
    return toggle[name].get()
  else
    local Utils = require("kostevski.utils")
    Utils.notify.error("Toggle '" .. name .. "' does not exist")
    return nil
  end
end

---Initialize all built-in toggles with keybindings
---
---Creates and registers all standard toggles for common Neovim features.
---Each toggle includes error handling and plugin availability checks.
---Should be called during Neovim initialization.
---
---Registered toggles:
---  - inlay_hints (<leader>th): LSP inlay hints
---  - relative_lineno (<leader>tl): Relative line numbers
---  - indent_guides (<leader>ti): Indent guide lines
---  - spell_check (<leader>tm): Spell checking
---  - line_wrap (<leader>tw): Line wrapping
---  - syntax_highlighting (<leader>tx): Syntax highlighting
---  - diagnostics (<leader>td): LSP diagnostics
---  - noneckpain (<leader>tn): NoNeckPain centering
---  - signature_help (<leader>ts): Auto signature help
---  - mouse (<leader>tM): Mouse support
---  - autoformat (<leader>tf): Format on save
---  - conceal (<leader>tc): Conceal level
---  - treesitter (<leader>tT): Treesitter highlighting
---
---@usage
---  require("kostevski.utils.toggle").setup()
function toggle.setup()
  local Utils = require("kostevski.utils")

  -- Inlay hints toggle
  toggle.create({
    name = "inlay_hints",
    get = function()
      return vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
    end,
    set = function(state)
      vim.lsp.inlay_hint.enable(state, { bufnr = 0 })
    end,
    keymap = "<leader>th",
    desc = "Inlay hints",
  })

  -- Relative line numbers
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

  -- Indent guides (with plugin check)
  toggle.create({
    name = "indent_guides",
    get = function()
      local ok, ibl = pcall(require, "ibl")
      if not ok then
        return false
      end
      local config = ibl.config.get_config(0)
      return config and config.enabled
    end,
    set = function(state)
      local ok, ibl = pcall(require, "ibl")
      if ok then
        ibl.setup_buffer(0, { enabled = state })
      end
    end,
    keymap = "<leader>ti",
    desc = "Indent guides",
  })

  -- Spell check
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

  -- Line wrap
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

  -- Syntax highlighting
  toggle.create({
    name = "syntax_highlighting",
    get = function()
      return vim.bo.syntax ~= "off"
    end,
    set = function(state)
      vim.bo.syntax = state and "on" or "off"
    end,
    keymap = "<leader>tx",
    desc = "Syntax highlighting",
  })

  -- Diagnostics
  toggle.create({
    name = "diagnostics",
    get = function()
      return vim.diagnostic.is_enabled()
    end,
    set = function(state)
      if state then
        vim.diagnostic.enable()
      else
        vim.diagnostic.enable(false)
      end
    end,
    keymap = "<leader>td",
    desc = "Vim diagnostics",
  })

  -- NoNeckPain (with plugin check)
  toggle.create({
    name = "noneckpain",
    get = function()
      -- NoNeckPain doesn't have a direct state check
      -- We'll use a buffer variable to track state
      return vim.b.noneckpain_enabled or false
    end,
    set = function(_)
      local ok = pcall(vim.cmd, "NoNeckPain")
      if ok then
        vim.b.noneckpain_enabled = not (vim.b.noneckpain_enabled or false)
      else
        Utils.notify.warn("NoNeckPain plugin not available")
      end
    end,
    keymap = "<leader>tn",
    desc = "No Neck Pain",
  })

  -- Signature help
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
            if vim.b.signature_help_enabled and #Utils.lsp.get_clients(0) > 0 then
              vim.lsp.buf.signature_help()
            end
          end,
          desc = "Show signature help",
        })
      else
        vim.api.nvim_clear_autocmds({
          buffer = 0,
          event = "CursorHoldI",
        })
      end
    end,
    keymap = "<leader>ts",
    desc = "Signature help",
  })

  -- Mouse support
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

  -- Formatting toggle
  toggle.create({
    name = "autoformat",
    get = function()
      return Utils.format and Utils.format.enabled() or false
    end,
    set = function(state)
      if Utils.format then
        Utils.format.enable(nil, state)
      end
    end,
    keymap = "<leader>tf",
    desc = "Auto format",
  })

  -- Conceal level
  toggle.create({
    name = "conceal",
    get = function()
      return vim.opt_local.conceallevel:get() > 0
    end,
    set = function(state)
      vim.opt_local.conceallevel = state and 2 or 0
    end,
    keymap = "<leader>tc",
    desc = "Conceal",
  })

  -- Treesitter highlighting
  toggle.create({
    name = "treesitter",
    get = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then
        return false
      end
      local buf = vim.api.nvim_get_current_buf()
      return configs.is_enabled("highlight", vim.bo[buf].filetype, buf)
    end,
    set = function(state)
      local ok = pcall(function()
        if state then
          vim.cmd("TSEnable highlight")
        else
          vim.cmd("TSDisable highlight")
        end
      end)
      if not ok then
        Utils.notify.warn("Treesitter not available")
      end
    end,
    keymap = "<leader>tT",
    desc = "Treesitter highlight",
  })
end

return toggle
