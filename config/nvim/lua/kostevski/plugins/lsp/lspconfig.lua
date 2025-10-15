local icons = Utils.ui.icons

return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason.nvim",
      { "mason-org/mason-lspconfig.nvim", config = function() end },
    },
    opts = function()
      local ret = {
        diagnostics = {
          underline = true,
          update_in_insert = false,
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = "●",
          },
          severity_sort = true,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = icons.diagnostics.ERROR,
              [vim.diagnostic.severity.WARN] = icons.diagnostics.WARN,
              [vim.diagnostic.severity.HINT] = icons.diagnostics.HINT,
              [vim.diagnostic.severity.INFO] = icons.diagnostics.INFO,
            },
          },
        },
        inlay_hints = {
          enabled = true,
        },
        codelens = {
          enabled = true,
        },
        folds = {
          enabled = true,
        },
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
        setup = {},
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
        Utils.lsp.on_supports_method("textDocument/inlayHint", function(client, buf)
          if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
            vim.lsp.inlay_hint.enable(true, { bufnr = buf })
          end
        end)
      end

      -- code lens
      if opts.codelens.enabled then
        Utils.lsp.on_supports_method("textDocument/codeLens", function(_, buffer)
          vim.lsp.codelens.refresh()
          vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = buffer,
            callback = vim.lsp.codelens.refresh,
          })
        end)
      end

      if opts.folds.enabled then
        Utils.lsp.on_supports_method("textDocument/foldingRange", function(_, buffer)
          vim.api.nvim_set_option_value("foldmethod", "expr", { scope = "local" })
          vim.api.nvim_set_option_value("foldexpr", "v:lua.vim.lsp.foldexpr()", { scope = "local" })
        end)
      end
      -- Setup diagnostics using the centralized module
      Utils.lsp.diagnostics.setup(opts.diagnostics)

      local servers = opts.servers
      local capabilities = Utils.lsp.capabilities.get_default_capabilities()

      -- Configure global LSP defaults using modern API
      vim.lsp.config("*", {
        capabilities = capabilities,
        root_markers = { ".git" },
      })

      -- Setup each server
      -- Neovim automatically merges configs from:
      -- 1. lsp/<server_name>.lua (if exists)
      -- 2. vim.lsp.config('*', {...}) global defaults
      -- 3. server_opts passed here
      -- local function setup(server_name, server_opts)
      --   server_opts = server_opts or {}
      --
      --   -- Check for custom setup function
      --   if opts.setup[server_name] then
      --     if type(opts.setup[server_name]) == "function" and opts.setup[server_name](server_name, server_opts) then
      --       return -- Custom setup handled it
      --     end
      --   elseif opts.setup["*"] then
      --     if type(opts.setup["*"]) == "function" and opts.setup["*"](server_name, server_opts) then
      --       return -- Custom setup handled it
      --     end
      --   end
      --
      --   -- Configure server if we have opts to apply
      --   if vim.tbl_count(server_opts) > 0 then
      --     vim.lsp.config(server_name, server_opts)
      --   end
      --
      --   -- Enable the server (Neovim handles file loading and merging)
      --   vim.lsp.enable(server_name)
      -- end

      -- Get all the servers that are available through mason-lspconfig

      local have_mason, mlsp = pcall(require, "mason-lspconfig")
      -- local mason_all = vim.tbl_keys(require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package) or {}
      local mason_all = have_mason
          and vim.tbl_keys(require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package)
        or {}
      local mason_exclude = {}

      ---@return boolean? exclude automatic setup
      local function configure(server)
        local sopts = opts.servers[server]
        sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts --[[@as lazyvim.lsp.Config]]

        if sopts.enabled == false then
          mason_exclude[#mason_exclude + 1] = server
          return
        end

        local use_mason = sopts.mason ~= false and vim.tbl_contains(mason_all, server)
        local setup = opts.setup[server] or opts.setup["*"]
        if setup and setup(server, sopts) then
          mason_exclude[#mason_exclude + 1] = server
        else
          vim.lsp.config(server, sopts) -- configure the server
          if not use_mason then
            vim.lsp.enable(server)
          end
        end
        return use_mason
      end

      local install = vim.tbl_filter(configure, vim.tbl_keys(opts.servers))
      if have_mason then
        require("mason-lspconfig").setup({
          ensure_installed = vim.list_extend(install, Utils.plugin.opts("mason-lspconfig.nvim").ensure_installed or {}),
          automatic_enable = { exclude = mason_exclude },
        })
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    name = "mason.nvim",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "stylua",
        "shfmt",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
      require("mason-lspconfig").setup({
        ensure_installed = vim.list_extend(opts.ensure_installed, {}),
      })
    end,
  },
}
