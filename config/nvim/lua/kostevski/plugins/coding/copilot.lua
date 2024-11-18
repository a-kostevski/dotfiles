local copilot = {}

function copilot.pick(kind)
   return function()
      local actions = require("CopilotChat.actions")
      local items = actions[kind .. "_actions"]()
      if not items then
         vim.notify("No " .. kind .. " found on the current line", vim.diagnostic.severity.WARN)
         return
      end
      require("CopilotChat.integrations.telescope").pick(items)
   end
end

return {
   {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      eveht = "InsertEnter",
      name = "copilot.lua",
      build = ":Copilot auth",
      opts = {
         suggestion = { enabled = false },
         panel = { enabled = false },
         filetypes = {
            markdown = true,
            help = true,
         },
      },
   },
   {
      "CopilotC-Nvim/CopilotChat.nvim",
      branch = "canary",
      cmd = "CopilotChat",
      dependencies = {
         { "nvim-telescope/telescope.nvim" }, -- Use telescope for help actions
         { "nvim-lua/plenary.nvim" },
      },
      build = "make tiktoken",
      keys = {
         { "<c-s>", "<CR>", ft = "copilot-chat", desc = "Submit Prompt", remap = true },
         { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
         {
            "<leader>aa",
            function()
               return require("CopilotChat").toggle()
            end,
            desc = "Toggle (CopilotChat)",
            mode = { "n", "v" },
         },
         {
            "<leader>ax",
            function()
               return require("CopilotChat").reset()
            end,
            desc = "Clear (CopilotChat)",
            mode = { "n", "v" },
         },
         {
            "<leader>aq",
            function()
               local input = vim.fn.input("Quick Chat: ")
               if input ~= "" then
                  require("CopilotChat").ask(input)
               end
            end,
            desc = "Quick Chat (CopilotChat)",
            mode = { "n", "v" },
         },
         -- Show help actions with telescope
         { "<leader>ad", copilot.pick("help"), desc = "Diagnostic Help (CopilotChat)", mode = { "n", "v" } },
         -- Show prompts actions with telescope
         { "<leader>ap", copilot.pick("prompt"), desc = "Prompt Actions (CopilotChat)", mode = { "n", "v" } },
      },
      opts = {
         context = "buffers",
         question_header = "  User ",
         answer_header = "  Copilot ",
         error_header = "  Error ",
         prompts = copilot.prompts,
         auto_follow_cursor = false,
         auto_insert_mode = true,
         show_help = true,
         mappings = {
            complete = {
               detail = "Use @<Tab> or /<Tab> for options.",
               insert = "<Tab>",
            },
            -- Close the chat
            close = {
               normal = "q",
               insert = "<C-c>",
            },
            -- Reset the chat buffer
            reset = {
               normal = "<C-x>",
               insert = "<C-x>",
            },
            -- Submit the prompt to Copilot
            submit_prompt = {
               normal = "<CR>",
               insert = "<C-s>",
            },
            -- Accept the diff
            accept_diff = {
               normal = "<C-y>",
               insert = "<C-y>",
            },
            -- Yank the diff in the response to register
            yank_diff = {
               normal = "gmy",
            },
            -- Show the diff
            show_diff = {
               normal = "gmd",
            },
            -- Show the prompt
            show_system_prompt = {
               normal = "gmp",
            },
            -- Show the user selection
            show_user_selection = {
               normal = "gms",
            },
            -- Show help
            show_help = {
               normal = "gmh",
            },
         },
      },
      config = function(_, opts)
         local chat = require("CopilotChat")
         local select = require("CopilotChat.select")
         opts.selection = select.unnamed
         opts.prompts = {
            -- Code related prompts
            Program = "You are an AI programming assistant. Follow the user's requirements carefully and to the letter. First, think step-by-step and describe your plan for what to build in pseudocode, written out in great detail. Then, output the code in a single code block. Minimize any other prose.",
            Refactor = "Please refactor the following code to improve its clarity and readability.",
            FixCode = "Please fix the following code to make it work as intended.",
            FixError = "Please explain the error in the following text and provide a solution.",
            BetterNamings = "Please provide better names for the following variables and functions.",
            Documentation = "Please provide documentation for the following code.",
            -- Text related prompts
            Concise = "Please rewrite the following text to make it more concise.",
            Explain = {
               prompt = "/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text.",
            },
            Review = {
               prompt = "/COPILOT_WORKSPACEW Review the selected code.",
            },
            Fix = {
               prompt = "/COPILOT_GENERATE There is a problem in this code. Rewrite the code to show it with the bug fixed.",
            },
            Optimize = {
               prompt = "/COPILOT_GENERATE Optimize the selected code to improve performance and readability.",
            },
            Docs = {
               prompt = "/COPILOT_GENERATE Please add documentation comment for the selection.",
            },
            Tests = {
               prompt = "/COPILOT_GENERATE Please generate tests for my code.",
            },
            FixDiagnostic = {
               prompt = "Please assist with the following diagnostic issue in file:",
               selection = select.diagnostics,
            },
            Commit = {
               prompt = "Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit.",
               selection = select.gitdiff,
            },
            CommitStaged = {
               prompt = "Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit.",
               selection = function(source)
                  return select.gitdiff(source, true)
               end,
            },
         }
         -- Override the git prompts message
         opts.prompts.Commit = {
            prompt = "Write commit message for the change with commitizen convention",
            selection = select.gitdiff,
         }
         opts.prompts.CommitStaged = {
            prompt = "Write commit message for the change with commitizen convention",
            selection = function(source)
               return select.gitdiff(source, true)
            end,
         }
         chat.setup(opts)

         chat.autocomplete = true

         vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
            chat.ask(args.args, { selection = select.visual })
         end, { nargs = "*", range = true })

         -- Restore CopilotChatBuffer
         vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
            chat.ask(args.args, { selection = select.buffer })
         end, { nargs = "*", range = true })

         vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "copilot-*",
            callback = function()
               vim.opt_local.relativenumber = true
               vim.opt_local.number = true

               -- Get current filetype and set it to markdown if the current filetype is copilot-chat
               local ft = vim.bo.filetype
               if ft == "copilot-chat" then
                  vim.bo.filetype = "markdown"
               end
            end,
         })
         vim.api.nvim_create_user_command("CopilotChatInline", function(args)
            chat.ask(args.args, {
               selection = select.visual,
               window = {
                  layout = "float",
                  relative = "cursor",
                  width = 1,
                  height = 0.4,
                  row = 1,
               },
            })
         end, { nargs = "*", range = true })
         vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "copilot-chat",
            callback = function()
               vim.opt_local.relativenumber = false
               vim.opt_local.number = false
            end,
         })

         chat.setup(opts)
      end,
   },
   -- {
   --    "saghen/blink.cmp",
   --    optional = true,
   --    dependencies = {
   --       {
   --          "giuxtaposition/blink-cmp-copilot",
   --          enabled = true, -- only enable if needed
   --          specs = {
   --             {
   --                "blink.cmp",
   --                optional = true,
   --                opts = {
   --                   sources = {
   --                      providers = {
   --                         copilot = { name = "copilot", module = "blink-cmp-copilot" },
   --                      },
   --                      completion = {
   --                         enabled_providers = { "copilot" },
   --                      },
   --                   },
   --                },
   --             },
   --          },
   --       },
   --    },
   -- },
}
