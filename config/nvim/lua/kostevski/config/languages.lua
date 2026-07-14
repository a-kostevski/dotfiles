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

local smoke_languages = vim.env.DOTFILES_NVIM_SMOKE_LANGUAGES
local enabled = smoke_languages and vim.split(smoke_languages, ",", { trimempty = true })
  or { "lua", "terraform", "cpp" }

return { enabled = enabled, overrides = {} }
