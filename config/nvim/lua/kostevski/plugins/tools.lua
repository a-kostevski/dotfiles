return {
   -- nvim-lua/plenary.nvim intentionally not declared standalone here: it is
   -- pulled in as a `dependencies` entry by several plugins (telescope,
   -- neo-tree, hardtime, lazygit, undotree, claude-code.nvim, ...). A bare
   -- top-level entry would flip lazy.nvim's merged `_.dep` flag to false
   -- (dep is AND-ed across every fragment for the plugin) and make it show
   -- up as never-loading in the Step 3 coverage check.
   { "echasnovski/mini.icons", event = "VeryLazy", opts = {} },
   { import = "kostevski.plugins.tools" },
}
