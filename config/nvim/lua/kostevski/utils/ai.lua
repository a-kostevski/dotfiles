---@class UtilsAi AI integration utilities
local AI = {}

-- Lazy load prompts
---@type table<string, table>?
local prompts = nil

---Get AI prompts with lazy loading
---@return table<string, table> prompts Prompt configurations by name
function AI.get_prompts()
   if not prompts then
      local ok, loaded_prompts = pcall(require, "kostevski.utils.ai.prompts")
      if ok then
         prompts = loaded_prompts
      else
         vim.notify("Failed to load AI prompts: " .. tostring(loaded_prompts), vim.log.levels.ERROR)
         prompts = {}
      end
   end
   return prompts
end

---Create a CopilotChat action from a prompt
---@param prompt_name string Name of the prompt
---@return fun()? action_function Action function or nil if prompt not found
function AI.create_action(prompt_name)
   local prompt_data = AI.get_prompts()[prompt_name]
   if not prompt_data then
      vim.notify(string.format("AI prompt '%s' not found", prompt_name), vim.log.levels.ERROR)
      return nil
   end

   return function()
      local ok, copilot_chat = pcall(require, "CopilotChat")
      if not ok then
         vim.notify("CopilotChat is not available", vim.log.levels.ERROR)
         return
      end

      -- Use the prompt configuration
      local prompt = prompt_data.prompt or ""
      local config = vim.tbl_deep_extend("force", {}, prompt_data, { prompt = nil })

      -- Execute the chat action
      local success, err = pcall(copilot_chat.ask, prompt, config)
      if not success then
         vim.notify("CopilotChat error: " .. tostring(err), vim.log.levels.ERROR)
      end
   end
end

---Pick a CopilotChat action using telescope
---@return fun() picker_function Function that shows the picker
function AI.pick()
   return function()
      -- Load required modules
      local ok_actions, actions = pcall(require, "CopilotChat.actions")
      if not ok_actions then
         vim.notify("Failed to load CopilotChat actions", vim.log.levels.ERROR)
         return
      end

      local ok_telescope, telescope = pcall(require, "CopilotChat.integrations.telescope")
      if not ok_telescope then
         vim.notify("Failed to load CopilotChat telescope integration", vim.log.levels.ERROR)
         return
      end

      -- Get available actions
      local items = actions.prompt_actions()
      if not items or vim.tbl_isempty(items) then
         vim.notify("No actions available", vim.log.levels.WARN)
         return
      end

      -- Show telescope picker
      telescope.pick(items, {
         selection = function(source)
            local ok_select, select = pcall(require, "CopilotChat.select")
            if ok_select then
               return select.buffer(source)
            end
            return nil
         end,
      })
   end
end

---@class AiMapping
---@field normal? string Normal mode keymap
---@field desc? string Description

---@class AiAttachOptions
---@field mappings table<string, AiMapping> Action name to mapping

---Setup keymaps for CopilotChat on buffer attach
---@param opts AiAttachOptions Options with mappings
function AI.on_attach(opts)
   if not opts or not opts.mappings then
      return
   end

   local ok_wk, which_key = pcall(require, "which-key")
   if not ok_wk then
      -- Fallback to regular keymaps
      for action, mapping in pairs(opts.mappings) do
         if mapping.normal then
            vim.keymap.set("n", mapping.normal, AI.create_action(action), {
               buffer = true,
               desc = mapping.desc or action,
            })
         end
      end
      return
   end

   -- Use which-key for better organization
   local map = {
      mode = { "n" },
      buffer = true,
      { "gm", group = "Copilot Actions" },
   }

   for action, mapping in pairs(opts.mappings) do
      if mapping.normal then
         table.insert(map, {
            mapping.normal,
            AI.create_action(action),
            desc = mapping.desc or action,
         })
      end
   end

   which_key.add(map)
end

---@class AiPromptConfig
---@field prompt string Prompt text
---@field selection? fun(): table Selection function
---@field [string] any Additional options

---Create a prompt handler with error handling
---@param prompt AiPromptConfig Prompt configuration
---@return fun() handler_function Handler function
function AI.create_prompt_handler(prompt)
   return function()
      local ok_chat, chat = pcall(require, "CopilotChat")
      if not ok_chat then
         vim.notify("CopilotChat is not available", vim.log.levels.ERROR)
         return
      end

      -- Prepare options
      local opts = vim.tbl_deep_extend("force", {
         selection = function()
            local ok_select, select = pcall(require, "CopilotChat.select")
            if ok_select then
               return select.buffer()
            end
            return nil
         end,
      }, prompt)

      -- Remove prompt from options
      local prompt_text = opts.prompt
      opts.prompt = nil

      -- Debug logging if enabled
      if vim.g.copilot_debug then
         local Utils = require("kostevski.utils")
         Utils.debug.dump(prompt_text)
      end

      -- Execute chat
      local success, err = pcall(chat.ask, prompt_text, opts)
      if not success then
         vim.notify("CopilotChat error: " .. tostring(err), vim.log.levels.ERROR)
      end
   end
end

---@class AiContextConfig
---@field input fun(callback: fun(path: string?)) Input selection function
---@field resolve fun(input: string?): table[] Resolution function

---Add workspace context for CopilotChat
---@return AiContextConfig context_configuration Context configuration
function AI.add_workspace_context()
   return {
      input = function(callback)
         -- Use telescope to select files
         local ok_telescope, telescope = pcall(require, "telescope.builtin")
         if ok_telescope then
            telescope.find_files({
               prompt_title = "Select files for context",
               attach_mappings = function(_, map)
                  map("i", "<CR>", function(prompt_bufnr)
                     local selection = require("telescope.actions.state").get_selected_entry()
                     require("telescope.actions").close(prompt_bufnr)
                     if selection and callback then
                        callback(selection.path)
                     end
                  end)
                  return true
               end,
            })
         else
            -- Fallback to system command
            local files = vim.fn.systemlist("fd -t f")
            vim.ui.select(files, {
               prompt = "Select files> ",
            }, callback)
         end
      end,

      resolve = function(input)
         if not input then
            return {}
         end

         -- Read file content
         local ok, content = pcall(vim.fn.readfile, input)
         if not ok then
            vim.notify("Failed to read file: " .. input, vim.log.levels.ERROR)
            return {}
         end

         return {
            {
               content = content,
               filename = input,
               filetype = vim.filetype.match({ filename = input }),
            },
         }
      end,
   }
end

-- Available contexts
---@type table<string, AiContextConfig>
AI.contexts = {
   add_workspace_context = AI.add_workspace_context(),
}

return AI
