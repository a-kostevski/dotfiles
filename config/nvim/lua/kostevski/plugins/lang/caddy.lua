local lang = require("kostevski.utils.lang")

return lang.register({
  name = "Caddyfile",
  root_markers = { ".git" },
  filetypes = { "Caddyfile" },
  additional_plugins = {
    { "isobit/vim-caddyfile" },
  },
})
