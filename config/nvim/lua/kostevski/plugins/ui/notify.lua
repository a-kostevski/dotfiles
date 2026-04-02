return {
   {
      "rcarriga/nvim-notify",
      name = "notify",
      init = function()
         vim.notify = require("notify")
      end,
      keys = {
         {
            "<leader>nd",
            function()
               require("notify").dismiss({ silent = true, pending = true })
            end,
            desc = "Dismiss All Notifications",
         },
      },
      opts = {
         timeout = 2500,
         max_width = 50,
         max_height = 10,
         top_down = true,
         render = "compact",
         stages = "slide",
         icons = {
            ERROR = "",
            WARN = "",
            INFO = "",
            DEBUG = "",
            TRACE = "",
         },
      },
      config = function(_, opts)
         require("notify").setup(opts)
         Utils.notify.setup()
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
