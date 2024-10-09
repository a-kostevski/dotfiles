return {
  'L3MON4D3/LuaSnip',
  build = 'make install_jsregexp',

  opts = {
    enable_autosnippets = true,
    store_selection_keys = '<Tab>',
  },
  config = function(plugin, opts)
    local snippet_path = vim.fn.stdpath('config') .. '/snippets'

    require('luasnip.loaders.from_lua').lazy_load({
      paths = { snippet_path },
    })
  end,
}
