return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff View" },
    { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close Diff View" },
    { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current)" },
    { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "Repo History" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = {
        layout = "diff3_mixed",
      },
    },
  },
}
