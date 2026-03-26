---@brief
---
--- https://clangd.llvm.org/
---
--- LLVM's language server for C/C++/Objective-C.

return {
  keys = {
    { "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
  },
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
  },
  root_markers = {
    "compile_commands.json",
    "compile_flags.txt",
    "configure.ac", -- AutoTools
    "Makefile",
    "configure.ac",
    "configure.in",
    "config.h.in",
    "meson.build",
    "meson_options.txt",
    "build.ninja",
    ".git",
  },
  capabilities = {
    offsetEncoding = { "utf-16" },
  },
  init_options = {
    usePlaceholders = true,
    completeUnimported = true,
    clangdFileStatus = true,
  },
}
