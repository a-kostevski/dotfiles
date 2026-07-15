return {
  "echasnovski/mini.surround",
  event = "VeryLazy",
  opts = {
    mappings = {
      add = "gsa",
      delete = "gsd",
      find = "gsf",
      find_left = "gsF",
      highlight = "gsh",
      replace = "gsr",
      update_n_lines = "gsn",
    },
  },
  keys = {
    { "gsa", desc = "Add Surrounding", mode = { "n", "v" } },
    { "gsd", desc = "Delete Surrounding" },
    { "gsf", desc = "Find Right Surrounding" },
    { "gsF", desc = "Find Left Surrounding" },
    { "gsh", desc = "Highlight Surrounding" },
    { "gsr", desc = "Replace Surrounding" },
    { "gsn", desc = "Update n lines" },
  },
}
