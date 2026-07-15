local lang = require("kostevski.utils.lang")

return lang.register({
  -- name must match this file's basename ("caddy") for enabling via
  -- config.languages; vim-caddyfile sets the lowercase "caddyfile" filetype
  name = "caddy",
  root_markers = { ".git" },
  filetypes = { "caddyfile" },
  additional_plugins = {
    { "isobit/vim-caddyfile" },
  },
})
