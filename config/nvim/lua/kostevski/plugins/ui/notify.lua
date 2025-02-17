return {
   {
      "rcarriga/nvim-notify",
      name = "notify",
      init = function()
         vim.notify = require("notify")
      end,
      keys = {
         -- {
         --    "<leader>nd",
         --    function()
         --       require("notify").dismiss({ silent = true, pending = true })
         --    end,
         --    desc = "Dismiss All Notifications",
         -- },
      },
      opts = Utils.notify.default_config,
      config = function(_, opts)
         require("notify").setup(opts)
      end,
   },
   {
      "nvim-telescope/telescope.nvim",
      optional = true,
      keys = {
         {
            "<leader>sn",
            function()
               require("telescope").extensions.notify.notify({})
            end,
            desc = "Notifications",
         },
      },
   },
}
