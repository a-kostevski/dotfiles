return {
   {
      "iamcco/markdown-preview.nvim",
      cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
      build = "cd app && yarn install",
      init = function()
         vim.g.mkdp_filetypes = { "markdown" }
      end,
      ft = { "markdown" },
   },
   {
      "mason.nvim",
      optional = true,
      opts = {
         ensure_installed = { "marksman", "markdownlint-cli2", "markdown-toc" },
      },
   },
   {
      "mfussenegger/nvim-lint",
      optional = true,
      opts = {
         linters_by_ft = {
            markdown = { "markdownlint-cli2" },
         },
      },
   },
   {
      "neovim/nvim-lspconfig",
      opts = {
         servers = {
            marksman = {},
         },
      },
   },
}
