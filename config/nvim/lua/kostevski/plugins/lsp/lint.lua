return {
  {
    "mfussenegger/nvim-lint",
    enabled = true,
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    opts = {
    events = { "BufWritePost", "BufReadPost", "InsertLeave" },
    linters_by_ft = {
      fish = { "fish" },
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
            Utils.notify.warn("Linter not found for " .. name)
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

      vim.api.nvim_create_user_command("LinterInfo", function()
        local lint = require("lint")
        local lines = {}
        local ft = vim.bo.filetype

        -- Header
        table.insert(lines, "# Linter Information")
        table.insert(lines, "")
        table.insert(lines, string.format("**Current filetype:** %s", ft ~= "" and ft or "(none)"))
        table.insert(lines, "")

        -- Linters for current filetype
        local ft_linters = lint._resolve_linter_by_ft(ft)
        if ft_linters and #ft_linters > 0 then
          table.insert(lines, "## Configured linters for current filetype:")
          for _, name in ipairs(ft_linters) do
            local linter = lint.linters[name]
            if linter then
              table.insert(lines, string.format("- **%s** (%s)", name, type(linter)))
            else
              table.insert(lines, string.format("- **%s** (not found)", name))
            end
          end
          table.insert(lines, "")
        else
          table.insert(lines, "## No linters configured for current filetype")
          table.insert(lines, "")
        end

        -- All configured linters by filetype
        table.insert(lines, "## All linters by filetype:")
        local has_linters = false
        for filetype, linter_names in pairs(lint.linters_by_ft) do
          has_linters = true
          table.insert(lines, string.format("- **%s**: %s", filetype, table.concat(linter_names, ", ")))
        end
        if not has_linters then
          table.insert(lines, "- (none)")
        end
        table.insert(lines, "")

        -- Available linters
        table.insert(lines, "## Available linters:")
        local linter_count = 0
        for name, _ in pairs(lint.linters) do
          linter_count = linter_count + 1
          table.insert(lines, string.format("- %s", name))
        end
        if linter_count == 0 then
          table.insert(lines, "- (none)")
        end

        -- Create a new buffer and display the info
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = "markdown"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].modifiable = false

        -- Open in a split
        vim.cmd("split")
        vim.api.nvim_win_set_buf(0, buf)
        vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
      end, {})
    end,
  },
}
