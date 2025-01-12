return {
   "akinsho/bufferline.nvim",
   event = "VeryLazy",
   dependencies = { "nvim-tree/nvim-web-devicons" },
   opts = {
      options = {
         close_command = function(buf)
            Utils.ui.bufremove(buf)
         end,
         right_mouse_command = function(buf)
            Utils.ui.bufremove(buf)
         end,
         diagnostics = "nvim_lsp",
         always_show_bufferline = false,
         offsets = {
            {
               filetype = "neo-tree",
               text = "File Explorer",
               highlight = "Directory",
            },
         },
      },
   },
   config = function(_, opts)
      if (vim.g.colors_name or ""):find("catppuccin") then
         opts.highlights = require("catppuccin.groups.integrations.bufferline").get()
      end
      require("bufferline").setup(opts)
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
         callback = function()
            vim.schedule(function()
               pcall(nvim_bufferline)
            end)
         end,
      })
   end,
}
