local icons = Utils.ui.icons

return {
   -- {
   --    "neovim/nvim-lspconfig",
   --    event = { "BufReadPre", "BufNewFile" },
   --    dependencies = {
   --       "mason",
   --       { "mason-org/mason-lspconfig.nvim", config = function() end },
   --    },
   -- opts = function()
   --    local ret = {
   --       diagnostics = {
   --          -- float = false,
   --          underline = true,
   --          update_in_insert = false,
   --          virtual_text = {
   --             spacing = 4,
   --             source = "if_many",
   --             prefix = "●",
   --          },
   --          severity_sort = true,
   --          signs = {
   --             text = {
   --                [vim.diagnostic.severity.ERROR] = icons.diagnostics.ERROR,
   --                [vim.diagnostic.severity.WARN] = icons.diagnostics.WARN,
   --                [vim.diagnostic.severity.HINT] = icons.diagnostics.HINT,
   --                [vim.diagnostic.severity.INFO] = icons.diagnostics.INFO,
   --             },
   --          },
   --       },
   --       inlay_hints = {
   --          enabled = true,
   --       },
   --       codelens = {
   --          enabled = false,
   --       },
   --       -- Enable lsp cursor word highlighting
   --       document_highlight = {
   --          enabled = true,
   --       },
   --
   --       capabilities = {
   --          workspace = {
   --             fileOperations = {
   --                didRename = true,
   --                willRename = true,
   --             },
   --          },
   --       },
   --       format = {
   --          formatting_options = nil,
   --          timeout_ms = nil,
   --       },
   --       servers = {
   --          bashls = {
   --             filetypes = { "sh", "bash", "zsh" },
   --          },
   --          lua_ls = {
   --             settings = {
   --                Lua = {
   --                   workspace = {
   --                      checkThirdParty = false,
   --                   },
   --                   codeLens = {
   --                      enable = true,
   --                   },
   --                   completion = {
   --                      callSnippet = "Replace",
   --                   },
   --                   doc = {
   --                      privateName = { "^_" },
   --                   },
   --                   hint = {
   --                      enable = true,
   --                      setType = false,
   --                      paramType = true,
   --                      paramName = "Disable",
   --                      semicolon = "Disable",
   --                      arrayIndex = "Disable",
   --                   },
   --                },
   --             },
   --          },
   --       },
   --       setup = {
   --          rust_analyzer = function()
   --             return true
   --          end,
   --       },
   --    }
   --    return ret
   -- end,

   -- config = function(_, opts)
   --    Utils.format.register(Utils.lsp.formatter())
   --    Utils.lsp.on_attach(function(client, buffer)
   --       require("kostevski.utils.keys").on_attach(client, buffer)
   --    end)
   --
   --    Utils.lsp.setup()
   --    Utils.lsp.on_dynamic_capability(require("kostevski.utils.keys").on_attach)
   --    Utils.lsp.words.setup(opts.document_highlight)
   --
   --    -- inlay hints
   --    if opts.inlay_hints.enabled then
   --       Utils.lsp.on_supports_method("textDocument/inlayHint", function(client, buf)
   --          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
   --             vim.lsp.inlay_hint.enable(true, { bufnr = buf })
   --          end
   --       end)
   --    end
   --
   --    -- code lens
   --    if opts.codelens.enable then
   --       Utils.lsp.on_supports_method("textDocument/codeLens", function(_, buffer)
   --          vim.lsp.codelens.refresh()
   --          vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
   --             buffer = buffer,
   --             callback = vim.lsp.codelens.refresh,
   --          })
   --       end)
   --    end
   --
   --    if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
   --       opts.diagnostics.virtual_text.prefix = vim.fn.has("nvim-0.10.0") == 0 and "●"
   --          or function(diagnostic)
   --             for d, icon in pairs(icons.diagnostics) do
   --                if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
   --                   return icon
   --                end
   --             end
   --          end
   --    end
   --
   --    vim.diagnostic.config(vim.deepcopy(opts.diagnostics))
   --    if opts.diagnostics.float == true then
   --       vim.api.nvim_create_autocmd("CursorHold", {
   --          callback = function()
   --             vim.diagnostic.open_float(nil, { focus = false })
   --          end,
   --       })
   --    end
   --
   --    local servers = opts.servers
   --    local capabilities = Utils.lsp.default_capabilities(opts)
   --
   --    local function setup(server)
   --       local server_opts = vim.tbl_deep_extend("force", {
   --          capabilities = vim.deepcopy(capabilities),
   --       }, servers[server] or {})
   --       if server_opts.enabled == false then
   --          return
   --       end
   --       if opts.setup[server] then
   --          if type(opts.setup[server]) == "function" and opts.setup[server](server, server_opts) then
   --             return
   --          end
   --       elseif opts.setup["*"] then
   --          if type(opts.setup["*"]) == "function" and opts.setup["*"](server, server_opts) then
   --             return
   --          end
   --       end
   --       require("lspconfig")[server].setup(server_opts)
   --    end
   --
   --    -- get all the servers that are available through mason-lspconfig
   --    local have_mason, mlsp = pcall(require, "mason-lspconfig")
   --    local all_mslp_servers = {}
   --    if have_mason then
   --       all_mslp_servers = vim.tbl_keys(require("mason-lspconfig.mappings.server").lspconfig_to_package)
   --    end
   --    local ensure_installed = {}
   --    for server, server_opts in pairs(servers) do
   --       if server_opts then
   --          server_opts = server_opts == true and {} or server_opts
   --          if server_opts.enabled ~= false then
   --             if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
   --                setup(server)
   --             else
   --                ensure_installed[#ensure_installed + 1] = server
   --             end
   --          end
   --       end
   --    end
   --
   --    Utils.debug.dump(ensure_installed)
   --
   --    mlsp.setup({
   --       automatic_installation = true,
   --       ensure_installed = vim.tbl_deep_extend(
   --          "force",
   --          ensure_installed or {},
   --          Utils.plugin.opts("mason-lspconfig").ensure_installed or {}
   --       ),
   --       handlers = { setup },
   --    })
   --
   -- LSP Signature Help
   -- vim.api.nvim_create_autocmd("CursorHoldI", {
   --    callback = function()
   --       vim.lsp.buf.signature_help()
   --    end,
   -- })
   --
   -- -- LSP Hover
   -- vim.api.nvim_create_autocmd("CursorHold", {
   --    callback = function()
   --       vim.lsp.buf.hover()
   --    end,
   -- })
   --
   -- -- LSP Diagnostics in Floating Window
   -- vim.api.nvim_create_autocmd("CursorHold", {
   --    callback = function()
   --       vim.diagnostic.open_float(nil, { focus = false })
   --    end,
   -- })
   --
   -- -- LSP Formatting on Save
   -- vim.api.nvim_create_autocmd("BufWritePre", {
   --    callback = function()
   --       vim.lsp.buf.format({ async = true })
   --    end,
   -- })

   --    -- LSP Code Actions
   --    vim.api.nvim_create_autocmd("CursorHold", {
   --       callback = function()
   --          vim.lsp.buf.code_action()
   --       end,
   --    })
   -- end,
   -- },
   {
      "mason-org/mason-lspconfig.nvim",
      opts = {},
      dependencies = {
         { "mason-org/mason.nvim", opts = {} },
         { "neovim/nvim-lspconfig" },
      },
   },
   {
      "mason-org/mason.nvim",
      name = "mason",
      opts_extend = { "ensure_installed" },
      main = true,
      opts = {
         ensure_installed = {
            "stylua",
            "shfmt",
         },
      },
      config = function(_, opts)
         require("mason").setup(opts)
      end,
   },
}
