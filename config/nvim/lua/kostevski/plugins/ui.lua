return {
  -- No standalone nui.nvim entry: every consumer declares it in dependencies,
  -- so a bare top-level entry is redundant.
  { import = "kostevski.plugins.ui" },
}
