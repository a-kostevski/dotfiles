local copilot = {}

function copilot.pick(kind)
   return function()
      local actions = require("CopilotChat.actions")
      local items = actions.prompt_actions()
      if not items then
         Utils.notify.warning("No " .. kind .. " found on the current line")
         return
      end
      require("CopilotChat.integrations.telescope").pick(items, {})
   end
end

return {
   {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      event = "InsertEnter",
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
         { "nvim-telescope/telescope.nvim" },
         { "nvim-lua/plenary.nvim" },
      },
      init = function()
         vim.g.ai_suggestions_enabled = false
      end,
      build = "make tiktoken",
      keys = {
         -- General AI commands
         mode = { "n", "v" },
         {
            "<leader>aa",
            function()
               return require("CopilotChat").toggle()
            end,
            desc = "Toggle",
            mode = { "n", "v" },
         },
         {
            "<leader>ax",
            function()
               return require("CopilotChat").reset()
            end,
            desc = "Clear",
         },
         {
            "<leader>aq",
            function()
               local input = vim.fn.input("Quick Chat: ")
               if input ~= "" then
                  require("CopilotChat").ask(input)
               end
            end,
            desc = "Quick Chat",
         },

         -- Code explanation and review
         { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "Explain code" },
         { "<leader>ar", "<cmd>CopilotChatReview<cr>", desc = "Review code" },
         { "<leader>aR", "<cmd>CopilotChatRefactor<cr>", desc = "Refactor code" },

         -- Test generation
         { "<leader>at", "<cmd>CopilotChatTests<cr>", desc = "Generate tests" },

         -- Diagnostic help
         { "<leader>ad", copilot.pick("diagnostic"), desc = "Diagnostic Help" },
         { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },

         -- Prompt actions
         { "<leader>ap", copilot.pick("prompt"), desc = "Prompt Actions (CopilotChat)" },
      },

      opts = {
         context = "buffer",
         question_header = "  User ",
         answer_header = "  Copilot ",
         error_header = "  Error ",
         auto_follow_cursor = false,
         auto_insert_mode = true,
         show_help = true,
         mappings = {
            complete = {
               detail = "Use @<Tab> or /<Tab> for options.",
               insert = "<Tab>",
               desc = "Complete",
            },
            close = {
               normal = "q",
               insert = "<C-c>",
               desc = "Close",
            },
            reset = {
               normal = "<C-x>",
               insert = "<C-x>",
               desc = "Reset",
            },
            submit_prompt = {
               normal = "<CR>",
               insert = "<C-s>",
               desc = "Submit Prompt",
            },
            accept_diff = {
               normal = "<C-y>",
               insert = "<C-y>",
               desc = "Accept Diff",
            },
            yank_diff = {
               normal = "gmy",
               desc = "Yank Diff",
            },
            show_diff = {
               normal = "gmd",
               desc = "Show Diff",
            },
            show_system_prompt = {
               normal = "gmp",
               desc = "Show System Prompt",
            },
            show_user_selection = {
               normal = "gms",
               desc = "Show User Selection",
            },
            show_help = {
               normal = "gmh",
               desc = "Show Help",
            },
         },

         prompts = {
            --    -- Code related prompts
            Program = {
               prompt = "You are an AI programming assistant. Follow the user's requirements carefully and to the letter. First, think step-by-step and describe your plan for what to build in pseudocode, written out in great detail. Then, output the code in a single code block. Minimize any other prose.",
            },
            Refactor = {
               prompt = "Please refactor the following code to improve its clarity and readability.",
            },
            FixCode = {
               prompt = "Please fix the following code to make it work as intended.",
            },
            FixDiagnostic = {
               prompt = "Please fix the diagnostic issue in the following code.",
            },
            FixError = {
               prompt = "Please explain the error in the following text and provide a solution.",
            },
            BetterNamings = {
               prompt = "Please provide better names for the following variables and functions.",
            },
            Documentation = {
               prompt = "Please provide documentation for the following code.",
            },
            Concise = {
               prompt = "Please rewrite the following text to make it more concise.",
            },
            Explain = {
               prompt = "/COPILOT_EXPLAIN Write an explanation for the active selection as paragraphs of text.",
            },
            Review = {
               prompt = "/COPILOT_WORKSPACE Review the selected code.",
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
            Commit = {
               prompt = "Write commit message for the change with commitizen convention. Make sure the title has maximum 50 characters and message is wrapped at 72 characters. Wrap the whole message in code block with language gitcommit.",
            },
         },
      },
      config = function(_, opts)
         local chat = require("CopilotChat")
         local select = require("CopilotChat.select")

         opts.selection = function(source)
            return select.visual(source) or select.buffer(source)
         end

         vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
            chat.ask(args.args, { selection = select.visual })
         end, { nargs = "*", range = true })

         vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
            chat.ask(args.args, { selection = select.buffer })
         end, { nargs = "*", range = true })

         vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "copilot-chat",
            callback = function()
               vim.opt_local.relativenumber = false
               vim.opt_local.number = false
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
         chat.setup(opts)
      end,
   },
   {
      "saghen/blink.cmp",
      optional = true,
      dependencies = {
         {
            "giuxtaposition/blink-cmp-copilot",
            enabled = vim.g.ai_suggestions_enabled,
            specs = {
               {
                  "blink.cmp",
                  optional = true,
                  opts = {
                     sources = {
                        providers = {
                           copilot = { name = "copilot", module = "blink-cmp-copilot" },
                        },
                        completion = {
                           enabled_providers = { "copilot" },
                        },
                     },
                  },
               },
            },
         },
      },
   },
}
