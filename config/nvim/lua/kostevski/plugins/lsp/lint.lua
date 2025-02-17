return {
   {
      "mfussenegger/nvim-lint",
      enabled = true,
      opts_extend = { "linters", "linters_by_ft" },
      opts = {
         events = { "BufWritePost", "BufReadPost", "InsertLeave" },
         linters_by_ft = {
            -- lua = { "luacheck" },
            zsh = { "zsh" },
         },
         linters = {},
      },
      config = function(_, opts)
         local M = {}

         local lint = require("lint")

         for name, linter in pairs(opts.linters) do
            if type(linter) == "table" and type(lint.linters[name]) == "table" then
               lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
               if type(linter.prepend_args) == "table" then
                  lint.linters[name].args = lint.linters[name].args or {}
                  vim.list_extend(lint.linters[name].args, linter.prepend_args)
               end
            else
               lint.linters[name] = linter
            end
         end
         lint.linters_by_ft = opts.linters_by_ft
         function M.lint()
            local names = lint._resolve_linter_by_ft(vim.bo.filetype)

            names = vim.list_extend({}, names)
            -- Add fallback linters.
            if #names == 0 then
               vim.list_extend(names, lint.linters_by_ft["_"] or {})
            end

            -- Add global linters.
            vim.list_extend(names, lint.linters_by_ft["*"] or {})

            -- Filter out linters that don't exist or don't match the condition.
            local ctx = { filename = vim.api.nvim_buf_get_name(0) }
            ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
            names = vim.tbl_filter(function(name)
               local linter = lint.linters[name]
               if not linter then
                  Utils.notify.warn("Linter not found for" .. name)
                  return false
               end
               -- if type(linter) == "table" and type(linter.condition) == "function" then
               --    return linter.condition(ctx)
               -- end
               -- return true
               return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
            end, names)

            -- Run linters.
            if #names > 0 then
               lint.try_lint(names)
            end
         end

         vim.api.nvim_create_autocmd(opts.events, {
            group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
            callback = Utils.debounce(100, M.lint),
         })

         local Info = {}

         function Info.info()
            local linters = require("lint").linters
            -- Use the custom Utils.notify API
            Utils.notify.info("Available linters:", {
               title = "Linter Information",
            })

            for name, linter in pairs(linters) do
               -- Show linter name
               Utils.notify.info(string.format("Linter: %s", name), { title = "Linter Details" })

               -- Show linter configuration
               Utils.notify.info(vim.inspect(linter), { title = string.format("%s Configuration", name) })
            end
         end
         vim.api.nvim_create_user_command("LinterInfo", Info.info, {})
      end,
   },
}
