return {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      workspace = {
        checkThirdParty = false,
      },
      completion = {
        callSnippet = "Replace",
      },
      diagnostics = {
        globals = {},
      },
      format = {
        enable = false,
      },
      hint = {
        enable = true,
      },
    },
  },
}
