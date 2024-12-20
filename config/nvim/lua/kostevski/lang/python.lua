-- Todo: Add python support
return {
   {
      "williamboman/mason.nvim",
      optional = true,
      opts = function(_, opts)
         opts.ensure_installed = opts.ensure_installed or {}
         opts.ensure_installed = vim.list_extend(opts.ensure_installed, {
            "isort",
            "black",
         })
      end,
   },
}
