-- Language Configuration
-- Controls which language support modules are loaded
--
-- Options:
--   enabled = "all"              -- Load all available languages
--   enabled = { "lua", "go" }    -- Load only specified languages
--
--   overrides = {                -- Per-language configuration overrides
--     python = { lsp_server = "pyright" },
--   }

return {
  enabled = { "lua", "terraform" },
  overrides = {},
}
