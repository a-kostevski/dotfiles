local lang = require("kostevski.utils.lang")

return lang.register({
  name = "cpp",
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
  native_lsp = true, -- lsp/clangd.lua handles LSP config
  root_markers = {
    -- Build systems
    "CMakeLists.txt",
    "Makefile",
    "makefile",
    "GNUmakefile",
    "meson.build",
    "meson_options.txt",
    "BUILD",
    "BUILD.bazel",
    "WORKSPACE",
    "WORKSPACE.bazel",
    -- Compilation databases
    "compile_commands.json",
    "compile_flags.txt",
    -- C/C++ config
    ".clangd",
    ".clang-format",
    ".clang-tidy",
    -- Package managers
    "conanfile.txt",
    "conanfile.py",
    "vcpkg.json",
    -- Common markers
    ".git",
  },
  lsp_server = "clangd",
  formatters = {
    list = { "clang-format" },
    tools = { "clang-format" },
  },
  linters = {
    list = { "cppcheck" },
    tools = { "cppcheck" },
  },
  dap = {
    adapters = {
      codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = { "--port", "${port}" },
        },
      },
    },
    configurations = {
      cpp = {
        {
          name = "Launch",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      },
      c = {
        {
          name = "Launch",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      },
    },
  },
  treesitter_parsers = { "c", "cpp", "cmake", "make", "doxygen" },
  mason_packages = { "codelldb" },
  settings = {
    expandtab = true,
    shiftwidth = 4,
    tabstop = 4,
    softtabstop = 4,
  },
  additional_plugins = {
    -- CMake integration
    {
      "Civitasv/cmake-tools.nvim",
      ft = { "c", "cpp", "cmake" },
      dependencies = { "nvim-lua/plenary.nvim" },
      opts = {},
    },
    {
      "p00f/clangd_extensions.nvim",
      ft = { "c", "cpp", "objc", "objcpp" },
      opts = {
        inlay_hints = {
          inline = false,
        },
        ast = {
          --These require codicons (https://github.com/microsoft/vscode-codicons)
          role_icons = {
            type = "",
            declaration = "",
            expression = "",
            specifier = "",
            statement = "",
            ["template argument"] = "",
          },
          kind_icons = {
            Compound = "",
            Recovery = "",
            TranslationUnit = "",
            PackExpansion = "",
            TemplateTypeParm = "",
            TemplateTemplateParm = "",
            TemplateParamObject = "",
          },
        },
      },
    },
  },
})
