local Lang = require("kostevski.utils.lang")

if not Lang.is_enabled("tex") then
  return Lang.disabled_server("texlab")
end

-- Root patterns for LaTeX projects
require("kostevski.utils.root").add_patterns("tex", {
  -- LaTeX project files
  "main.tex",
  "document.tex",
  "thesis.tex",
  "paper.tex",
  "report.tex",
  "book.tex",
  "article.tex",
  -- LaTeX build files
  ".latexmkrc",
  "latexmkrc",
  "Makefile",
  -- Bibliography
  "references.bib",
  "bibliography.bib",
  "refs.bib",
  "sources.bib",
  "*.bib",
  -- LaTeX auxiliary files (in project root)
  "*.cls",
  "*.sty",
  -- Build directories
  "build/",
  "out/",
  -- Project structure
  "chapters/",
  "sections/",
  "figures/",
  "images/",
  "graphics/",
})

-- Editor options for tex buffers (moved from lsp/texlab.lua so they only
-- apply when this language is enabled)
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("kostevski_lang_tex", { clear = true }),
  pattern = { "tex", "plaintex" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.textwidth = 80
  end,
})

return {
  -- Formatter Configuration
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        tex = { "latexindent" },
      },
    },
  },

  -- Additional Tools
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "latex" })
      end
    end,
  },

  -- VimTeX Integration
  {
    "lervag/vimtex",
    lazy = false,
    config = function()
      vim.g.vimtex_view_method = "skim"
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_quickfix_mode = 0
    end,
  },
}
