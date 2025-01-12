local copilot = {}

copilot.prompts = require("kostevski.utils.ai.prompts")

-- local function load_module(module_name)
--    local module, success, err = nil, pcall(function()
--       return require(module_name)
--    end)
--    if not success then
--       Utils.notify.error("Failed to load " .. module_name .. ": " .. err)
--       return nil
--    end
--    return module
-- end

copilot.create_action = function(prompt_name)
   return function()
      require("CopilotChat").ask(copilot.prompts[prompt_name].prompt, {
         copilot.prompts[prompt_name],
      })
   end
end

copilot.contexts = {
   add_workspace_context = {
      input = function(callback)
         vim.fn.systemlist("fd -t f"):select({
            prompt = "Select files> ",
         }, callback)
      end,
      resolve = function(input)
         return {
            {
               content = vim.fn.readfile(input),
               filename = input,
               filetype = vim.filetype.match({ filename = input }),
            },
         }
      end,
   },
}

function copilot.pick()
   return function()
      local actions = Utils.try(function()
         return require("CopilotChat.actions")
      end, { msg = "Failed to load Copilotchat.actions" })

      if not actions then
         return
      end

      local items = actions.prompt_actions()
      if not items then
         Utils.notify.warn("No actions found on the current line")
         return
      end

      local telescope = Utils.try(function()
         return require("CopilotChat.integrations.telescope")
      end, { msg = "Failed to load telescope" })

      if not telescope then
         return
      end

      telescope.pick(items, {
         selection = function(source)
            return require("CopilotChat.select").buffer(source)
         end,
      })
   end
end

function copilot.on_attach(opts)
   local map = {
      mode = { "n" },
      buffer = true,
      { "gm", group = "Copilot Actions" },
   }

   for action, mapping in pairs(opts.mappings) do
      if mapping.normal then
         map[#map + 1] = { mapping.normal, desc = mapping.desc or action }
      end
   end
   require("which-key").add(map)
end

local function safe_ask(chat, prompt, opts)
   opts = vim.tbl_deep_extend("force", {
      selection = require("CopilotChat.select").buffer,
   }, opts or {})
   Utils.debug.dump(prompt)
   local success, err = pcall(function()
      chat.ask(prompt, opts)
   end)

   if not success then
      vim.notify("CopilotChat error: " .. tostring(err), vim.log.levels.ERROR)
   end
end

function copilot.create_prompt_handler(prompt)
   return function()
      local chat = require("CopilotChat")
      safe_ask(chat, prompt.prompt, prompt)
   end
end
return copilot
