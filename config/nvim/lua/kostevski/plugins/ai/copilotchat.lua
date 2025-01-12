local copilot = require("kostevski.utils.ai")

return {
   {
      "CopilotC-Nvim/CopilotChat.nvim",
      branch = "main",
      cmd = "CopilotChat",
      lazy = false,
      dependencies = {
         { "nvim-telescope/telescope.nvim" },
         { "nvim-lua/plenary.nvim" },
      },
      build = "make tiktoken",

      keys = {

         mode = { "n", "v" },
         {
            "<leader>aa",
            function()
               return require("CopilotChat").toggle()
            end,
            desc = "Toggle",
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
                  require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
               end
            end,
            desc = "Quick Chat",
         },
         {
            "<leader>af",
            copilot.create_prompt_handler(copilot.prompts.FixDiagnostic),
            desc = "Fix",
         },
         {
            "<leader>ad",
            copilot.create_prompt_handler(copilot.prompts.FixDiagnostic),
            desc = "Diagnostics",
         },
         {
            "<leader>aD",
            copilot.create_prompt_handler(copilot.prompts.Documentation),
            desc = "Docs",
         },
         { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "Explain code" },

         { "<leader>as", "<cmd>CopilotChatStop<cr>", desc = "Stop copilot" },
         { "<leader>ai", "<cmd>CopilotChatInline<cr>", desc = "Inline chat" },
         {
            "<leader>ar",
            copilot.create_prompt_handler(copilot.prompts.ReviewSecurityAndLogic),
            desc = "Review code",
         },
         {
            "<leader>aR",
            copilot.create_prompt_handler(copilot.prompts.ReviewChain),
            desc = "Reviewchain code",
         },
         { "<leader>at", "<cmd>CopilotChatTests<cr>", desc = "Generate tests" },

         -- Prompt actions
         {
            "<leader>ap",
            copilot.pick(),
            desc = "Prompt Actions",
         },
      },
      opts = {
         model = "claude-3.5-sonnet",
         -- model = "gpt-4o",
         question_header = "  User ",
         answer_header = "  Copilot ",
         error_header = "  Error ",
         chat_autocomplete = false,
         auto_follow_cursor = false,
         highlight_headers = false,
         mappings = {
            complete = {
               insert = "<Tab>",
               desc = "Complete",
            },
            close = {
               normal = "q",
               insert = "<C-c>",
               desc = "Close",
            },
            reset = {
               normal = "<C-l>",
               insert = "<C-l>",
               desc = "Reset",
            },
            submit_prompt = {
               normal = "<CR>",
               insert = "<C-s>",
               desc = "Submit Prompt",
            },
            toggle_sticky = {
               normal = "gmr",
               desc = "Toggle sticky line",
            },
            accept_diff = {
               normal = "<C-y>",
               insert = "<C-y>",
               desc = "Accept Diff",
            },
            jump_to_diff = {
               normal = "gmj",
               desc = "Jump to diff",
            },
            quickfix_diffs = {
               normal = "gmq",
               desc = "Quickfix diffs",
            },
            yank_diff = {
               normal = "gmy",
               desc = "Yank Diff",
            },
            show_diff = {
               normal = "gmd",
               desc = "Show Diff",
            },
            show_info = {
               normal = "gmi",
               desc = "Show System Prompt",
            },
            show_context = {
               normal = "gmc",
               desc = "Show User Context",
            },
            show_help = {
               normal = "gmh",
               desc = "Show Help",
            },
         },
         --
         -- window = {
         --    width = 0.4,
         -- },
      },
      config = function(_, opts)
         local chat = require("CopilotChat")
         local select = require("CopilotChat.select")
         opts.prompts = vim.tbl_extend("keep", copilot.prompts, opts.prompts or {})

         opts.selection = function(source)
            return select.visual(source) or select.buffer(source)
         end
         chat.setup(opts)

         vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "copilot-*",
            callback = function(_)
               vim.opt_local.relativenumber = false
               vim.opt_local.number = false
            end,
         })

         vim.api.nvim_create_autocmd("VimLeavePre", {
            pattern = "copilot-*",
            callback = function(ev)
               vim.api.nvim_buf_delete(ev.buf, { force = true })
            end,
         })

         vim.api.nvim_create_user_command("CopilotChatInline", function(args)
            chat.toggle({
               window = {
                  relative = "cursor",
                  width = 1,
                  height = 0.4,
                  row = 1,
                  layout = "float",
               },
            })

            chat.ask(args.args, {
               selection = select.buffer,
            })
         end, { nargs = "*", range = true })
      end,
   },
}
