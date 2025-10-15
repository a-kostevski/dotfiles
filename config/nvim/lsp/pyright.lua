local function set_python_path(path)
   local clients = vim.lsp.get_clients({
      bufnr = vim.api.nvim_get_current_buf(),
      name = "pyright",
   })
   for _, client in ipairs(clients) do
      if client.settings then
         client.settings.python = vim.tbl_deep_extend("force", client.settings.python, { pythonPath = path })
      else
         client.config.settings =
            vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = path } })
      end
      client.notify("workspace/didChangeConfiguration", { settings = nil })
   end
end

return {
   cmd = { "pyright-langserver", "--stdio" },
   filetypes = { "python" },
   root_markers = {
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      "Pipfile",
      "pyrightconfig.json",
      ".git",
   },
   settings = {
      python = {
         analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = "workspace",
         },
         venvPath = ".", -- Look for virtual environments in the workspace root
         pythonPath = ".venv/bin/python", -- Path to Python interpreter in the venv
      },
   },
   before_init = function(_, config)
      -- Get the real workspace root
      local workspace_root = vim.fn.getcwd()
      -- Update the Python path to use absolute path to the virtual environment
      config.settings.python.pythonPath = workspace_root .. "/.venv/bin/python"
   end,
   flags = {
      debounce_text_changes = 150,
   },
   on_attach = function(client, bufnr)
      vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightOrganizeImports", function()
         client:exec_cmd({
            command = "pyright.organizeimports",
            arguments = { vim.uri_from_bufnr(bufnr) },
         })
      end, {
         desc = "Organize Imports",
      })
      vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", set_python_path, {
         desc = "Reconfigure pyright with the provided python path",
         nargs = 1,
         complete = "file",
      })
   end,
}
