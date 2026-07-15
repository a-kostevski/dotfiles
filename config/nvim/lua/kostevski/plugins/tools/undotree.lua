return {
  "mbbill/undotree",
  name = "undotree",
  cmd = { "UndotreeToggle", "UndotreeShow" },
  keys = {
    -- UndotreeToggle is already a toggle; no Utils.toggle wrapper needed
    -- (the old one double-mapped <leader>tu and tracked a state var that
    -- never updated)
    { "<leader>tu", "<cmd>UndotreeToggle<cr>", desc = "Undotree" },
  },
}
