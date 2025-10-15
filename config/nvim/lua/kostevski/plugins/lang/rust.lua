-- Root patterns for Rust projects
require("kostevski.utils.root").add_patterns("rust", {
  -- Rust-specific
  "Cargo.toml",
  "Cargo.lock",
  "rust-project.json",
  "rustfmt.toml",
  ".rustfmt.toml",
  "clippy.toml",
  ".clippy.toml",
  "rust-toolchain",
  "rust-toolchain.toml",
  ".cargo/config.toml",
  ".cargo/config",
  -- Workspace
  "workspace.toml",
  -- Testing
  "tests/",
  "benches/",
  "examples/",
  -- Build
  "build.rs",
  "Makefile",
  "justfile",
})

return {
  -- Formatter Configuration
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
      },
      formatters = {
        rustfmt = {
          args = { "--edition", "2021" },
        },
      },
    },
  },

  -- Linter Configuration
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        rust = { "clippy" },
      },
    },
  },

  -- Additional Tools
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "rust", "toml" })
      end
    end,
  },

  -- Crates.io integration
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {
      src = {
        cmp = { enabled = true },
      },
    },
  },
}
