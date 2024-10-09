return {
    "williamboman/mason.nvim",
    dependencies = {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    keys = {},
    build = ":MasonUpdate",

    opts_extend = { "ensure_installed" },
    opts = {
        ensure_installed = {
            "stylua",
            "shfmt",
        },
    },
    config = function(_, opts)
        require("mason").setup({ opts })


        require("mason-tool-installer").setup({
            ensure_installed = opts.ensure_installed,

            integrations = { ['mason-lspconfig'] = true, }
        })
    end
}
