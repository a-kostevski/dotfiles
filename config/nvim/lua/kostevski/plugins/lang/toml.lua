local lang = require("kostevski.utils.lang")

return lang.register({
  name = "toml",
  filetypes = { "toml" },
  root_markers = {
    -- Rust
    "Cargo.toml",
    "rustfmt.toml",
    ".cargo/config.toml",
    -- Python
    "pyproject.toml",
    "poetry.toml",
    "pdm.toml",
    -- General configs
    "taplo.toml",
    ".taplo.toml",
    "starship.toml",
    "config.toml",
    "settings.toml",
  },
  lsp_server = "taplo",
  formatters = {
    list = { "taplo" },
    tools = { "taplo" },
  },
  treesitter_parsers = { "toml" },
})
