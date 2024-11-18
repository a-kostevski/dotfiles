return {
   {
      "ahmedkhalf/project.nvim",
      opts = {
         manual_mode = true,
         patterns = {
            ".git",
            ".hg",
            ".svn",
            ".bzr",
            "lua",
            "Makefile",
            "package.json",
            "Cargo.toml",
            "yarn.lock",
         },
         ignore_lsp = { "efm", "sumneko_lua", "tsserver" },
      },
      config = function(_, opts)
         require("project_nvim").setup(opts)
         Utils.plugin.on_load("telescope", function()
            require("telescope").load_extension("projects")
         end)
      end,
   },
   {
      "nvim-telescope/telescope.nvim",
      optional = true,
      keys = {
         {
            "<leader>fp",
            function()
               vim.cmd("Telescope projects")
            end,
            desc = "Projects",
         },
      },
   },
}
