return {
   "neovim/nvim-lspconfig",
   name = "nvim-lspconfig",
   event = { "BufReadPre", "BufNewFile" },
   dependencies = {

      { "williamboman/mason-lspconfig.nvim", config = function() end },
      -- "hrsh7th/cmp-nvim-lsp",
   },
   opts = function()
      local ret = {
         diagnostics = {
            underline = true,
            update_in_insert = false,
            virtual_text = {
               spacing = 2,
               source = "if_many",
               prefix = "●",
            },
            severity_sort = true,
            signs = {
               text = {
                  [vim.diagnostic.severity.ERROR] = " ",
                  [vim.diagnostic.severity.WARN] = " ",
                  [vim.diagnostic.severity.HINT] = " ",
                  [vim.diagnostic.severity.INFO] = " ",
               },
            },
         },
         inlay_hints = {
            enabled = true,
         },
         codelens = {
            enabled = false,
         },
         -- Enable lsp cursor word highlighting
         document_highlight = {
            enabled = true,
         },

         capabilities = {
            workspace = {
               fileOperations = {
                  didRename = true,
                  willRename = true,
               },
            },
         },
         format = {
            formatting_options = nil,
            timeout_ms = nil,
         },
         setup = {
            rust_analyzer = function()
               return true
            end,
         },

         servers = {
            lua_ls = {
               settings = {
                  Lua = {
                     workspace = {
                        checkThirdParty = false,
                     },
                     codeLens = {
                        enable = true,
                     },
                     completion = {
                        callSnippet = "Replace",
                     },
                     doc = {
                        privateName = { "^_" },
                     },
                     hint = {
                        enable = true,
                        setType = false,
                        paramType = true,
                        paramName = "Disable",
                        semicolon = "Disable",
                        arrayIndex = "Disable",
                     },
                  },
               },
            },
         },
      }
      return ret
   end,

   config = function(_, opts)
      Utils.format.register(Utils.lsp.formatter())
      Utils.lsp.on_attach(function(client, buffer)
         require("kostevski.utils.keys").on_attach(client, buffer)
      end)

      Utils.lsp.setup()
      Utils.lsp.on_dynamic_capability(require("kostevski.utils.keys").on_attach)
      Utils.lsp.words.setup(opts.document_highlight)

      -- inlay hints
      if opts.inlay_hints.enabled then
         Utils.lsp.on_supports_method("textDocument/inlayHint", function(client, buffer)
            if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == "" then
               vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
            end
         end)
      end

      -- code lens
      if opts.codelens.enable then
         Utils.lsp.on_supports_method("textDocument/codeLens", function(client, buffer)
            vim.lsp.codelens.refresh()
            vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
               buffer = buffer,
               callback = vim.lsp.codelens.refresh,
            })
         end)
      end

      if type(opts.diagnostics.virtual_text) == "table" and opts.diagnostics.virtual_text.prefix == "icons" then
         opts.diagnostics.virtual_text.prefix = vim.fn.has("nvim-0.10.0") == 0 and "●"
            or function(diagnostic)
               local icons = Utils.ui.icons.diagnostics
               for d, icon in pairs(icons) do
                  if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
                     return icon
                  end
               end
            end
      end

      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))
      -- vim.api.nvim_create_autocmd("CursorHold", {
      --    callback = function()
      --       vim.diagnostic.open_float(nil, { focus = false })
      --    end,
      -- })

      local servers = opts.servers
      local capabilities = Utils.lsp.default_capabilities(opts)

      local function setup(server)
         local server_opts = vim.tbl_deep_extend("force", {
            capabilities = vim.deepcopy(capabilities),
         }, servers[server] or {})
         if server_opts.enabled == false then
            return
         end
         if opts.setup[server] then
            if opts.setup[server](server, server_opts) then
               return
            end
         elseif opts.setup["*"] then
            if opts.setup["*"](server, server_opts) then
               return
            end
         end
         require("lspconfig")[server].setup(server_opts)
      end

      -- get all the servers that are available through mason-lspconfig
      local have_mason, mlsp = pcall(require, "mason-lspconfig")
      local all_mslp_servers = {}
      if have_mason then
         all_mslp_servers = vim.tbl_keys(require("mason-lspconfig.mappings.server").lspconfig_to_package)
      end
      local ensure_installed = {}
      for server, server_opts in pairs(servers) do
         if server_opts then
            server_opts = server_opts == true and {} or server_opts
            if server_opts.enabled ~= false then
               -- run manual setup if mason=false or if this is a server that cannot be installed with mason-lspconfig
               if server_opts.mason == false or not vim.tbl_contains(all_mslp_servers, server) then
                  setup(server)
               else
                  ensure_installed[#ensure_installed + 1] = server
               end
            end
         end
      end

      if have_mason then
         mlsp.setup({
            ensure_installed = vim.tbl_deep_extend("force", ensure_installed or {}, mlsp.ensure_installed or {}),
            handlers = { setup },
         })
      end
   end,
}
