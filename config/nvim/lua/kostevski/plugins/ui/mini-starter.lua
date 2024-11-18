return {
   "echasnovski/mini.starter",
   version = false,
   event = "VimEnter",
   opts = function()
      local pad = string.rep(" ", 2)
      local new_section = function(name, action, section)
         return { name = name, action = action, section = pad .. section }
      end

      local ff = function()
         require("telescope.builtin").find_files()
      end
      local of = function()
         require("telescope.builtin").oldfiles()
      end
      local lg = function()
         require("telescope.builtin").live_grep()
      end
      local cf = function()
         require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
      end

      local pp = function()
         vim.cmd("Telescope projects")
      end

      local sr = function()
         require("persistence").load()
      end

      local starter = require("mini.starter")
      local opts = {
         evaluate_single = true,
         items = {
            new_section("Project", pp, "Project"),
            new_section("File", ff, "Telescope"),
            new_section("New File", "ene | startinsert", "Built-in"),
            new_section("Recent", of, "Telescope"),
            new_section("Text", lg, "Telescope"),
            new_section("Config", cf, "Config"),
            new_section("Restore", sr, "Session"),
            new_section("Quit", "qa", "Built-in"),
         },
         content_hooks = {
            starter.gen_hook.adding_bullet(pad .. "░ ", false),
            starter.gen_hook.aligning("center", "center"),
         },
      }
      return opts
   end,
   config = function(_, opts)
      local starter = require("mini.starter")
      starter.setup(opts)

      vim.api.nvim_create_autocmd("User", {
         pattern = "lazyVimStarted",
         callback = function(ev)
            local stats = require("lazy").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
            local pad_footer = string.rep(" ", 8)
            starter.config.footer = pad_footer .. "⚡ Neovim loaded " .. stats.count .. " plugins in " .. ms .. "ms"
            -- INFO: based on @echasnovski's recommendation (thanks a lot!!!)
            if vim.bo[ev.buf].filetype == "ministarter" then
               pcall(starter.refresh)
            end
         end,
      })
   end,
}
