local lang = require("kostevski.utils.lang")

return lang.register({
  name = "terraform",
  filetypes = { "terraform", "terraform-vars", "hcl" },
  lsp_server = "terraformls",
  root_markers = {
    ".terraform",
    "*.tf",
    "terraform.tfstate",
    ".terraform.lock.hcl",
  },
  formatters = {
    list = { "tofu" },
    tools = {}, -- tofu installed separately, not via mason
    config = {
      tofu = {
        command = "tofu",
        args = { "fmt", "-" },
        stdin = true,
      },
    },
  },
  linters = {
    list = { "tflint" },
    tools = { "tflint" },
  },
  treesitter_parsers = { "terraform", "hcl" },
  settings = {
    expandtab = true,
    shiftwidth = 2,
    tabstop = 2,
  },
})
