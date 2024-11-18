return {
   "nvim-lualine/lualine.nvim",
   init = function()
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then
         -- set an empty statusline till lualine loads
         vim.o.statusline = " "
      else
         -- hide the statusline on the starter page
         vim.o.laststatus = 0
      end
   end,
   dependencies = { "nvim-tree/nvim-web-devicons" },
   opts = function()
      vim.o.laststatus = vim.g.lualine_laststatus
      local opts = {
         options = {
            theme = "auto",
            globalstatus = vim.o.laststatus == 3,
            disabled_filetypes = {
               statusline = { "ministarter" },
            },
         },
         sections = {
            lualine_c = {
               { "filename" },
               {
                  function()
                     ---@diagnostic disable-next-line: undefined-field
                     return require("noice").api.status.mode.get()
                  end,
                  cond = function()
                     ---@diagnostic disable-next-line: undefined-field
                     return package.loaded["noice"] and require("noice").api.status.mode.has()
                  end,
                  fmt = function()
                     local recording_register = vim.fn.reg_recording()
                     if recording_register == "" then
                        return ""
                     else
                        return "Recording @" .. recording_register
                     end
                  end,
               },
            },
         },
         extensions = { "neo-tree" },
      }
      return opts
   end,
}
