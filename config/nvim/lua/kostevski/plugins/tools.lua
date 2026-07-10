return {
   -- No standalone plenary.nvim entry: every consumer (telescope, neo-tree,
   -- hardtime, lazygit, undotree, claude-code.nvim, ...) declares it in
   -- dependencies, so a bare top-level entry is redundant.
   { "echasnovski/mini.icons", event = "VeryLazy", opts = {} },
   { import = "kostevski.plugins.tools" },
}
