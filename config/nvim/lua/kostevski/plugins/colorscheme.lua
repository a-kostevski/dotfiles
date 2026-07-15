return {
  { "catppuccin/nvim", name = "catppuccin", enabled = false },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      vim.cmd.colorscheme("tokyonight")
    end,
    opts = {
      style = "night",
    },
  },
  { "shaunsingh/nord.nvim", enabled = false },
}
