-- Add autocmd to ensure proper tab handling for Makefiles
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "make", "makefile" },
  callback = function()
    -- Ensure tabs are visible
    local listchars = vim.opt.listchars:get()
    listchars.tab = "▸ "
    listchars.trail = "·"
    vim.opt_local.listchars = listchars
    vim.opt_local.list = true

    -- Highlight problematic spaces in Makefiles
    vim.cmd([[
         syntax match MakefileError /^\s\+/
         highlight link MakefileError Error
      ]])
  end,
})

local lang = require("kostevski.utils.lang")
return lang.register({
  name = "makefile",
  filetypes = { "make", "makefile" },
  root_markers = {
    -- Makefile variants
    "Makefile",
    "makefile",
    "GNUmakefile",
    "Makefile.am",
    "Makefile.in",
    -- Autotools
    "configure.ac",
    "configure.in",
    "autogen.sh",
    -- CMake
    "CMakeLists.txt",
    "cmake",
    -- Build systems
    "meson.build",
    "SConstruct",
    "Rakefile",
    -- Project indicators
    ".git",
    "build",
    "dist",
  },
  lsp_server = {
    name = "autotools_ls",
    config = {
      filetypes = { "make", "makefile", "automake" },
      single_file_support = true,
      settings = {},
    },
  },
  formatters = {
    -- Note: Makefiles are sensitive to formatting, especially tabs vs spaces
    -- Most formatters can break Makefiles, so we don't include any by default
    list = {},
    tools = {},
  },
  linters = {
    list = { "checkmake" },
    tools = { "checkmake" },
    config = {
      checkmake = {
        args = { "--format", "{{.LineNumber}}:{{.Violation}}", "$FILENAME" },
      },
    },
  },
  treesitter_parsers = { "make" },
  settings = {
    -- Makefiles require tabs, not spaces
    expandtab = false,
    shiftwidth = 8,
    tabstop = 8,
    softtabstop = 8,
    -- Help visualize tabs vs spaces
    list = true,
    listchars = vim.opt.listchars:get(),
  },
  additional_plugins = {
    -- Makefile-specific enhancements
    {
      "mechatroner/rainbow_csv",
      ft = { "make", "makefile" },
      optional = true,
    },
    -- Enhanced syntax highlighting
    {
      "vim-scripts/make.vim",
      ft = { "make", "makefile" },
      optional = true,
    },
  },
})
