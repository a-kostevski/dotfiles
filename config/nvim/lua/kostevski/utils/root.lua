local root = setmetatable({}, {
   __call = function(root)
      return root.get()
   end,
})

root.spec = { "lsp", { ".git", "lua" }, "cwd" }

root.detectors = {}

function root.detectors.cwd()
   return { vim.uv.cwd() }
end

function root.detectors.lsp(buf)
   local bufpath = root.bufpath(buf)
   if not bufpath then
      return {}
   end
   local roots = {}
   local clients = Utils.lsp.get_clients({ bufnr = buf })
   clients = vim.tbl_filter(function(client)
      return not vim.tbl_contains(vim.g.root_lsp_ignore or {}, client.name)
   end, clients)
   for _, client in pairs(clients) do
      local workspace = client.config.workspace_folders
      for _, ws in pairs(workspace or {}) do
         roots[#roots + 1] = vim.uri_to_fname(ws.uri)
      end
      if client.root_dir then
         roots[#roots + 1] = client.root_dir
      end
   end
   return vim.tbl_filter(function(path)
      path = Utils.norm(path)
      return path and bufpath:find(path, 1, true) == 1
   end, roots)
end

function root.detectors.pattern(buf, patterns)
   patterns = type(patterns) == "string" and { patterns } or patterns
   local path = root.bufpath(buf) or vim.uv.cwd()
   local pattern = vim.fs.find(function(name)
      for _, p in ipairs(patterns) do
         if name == p then
            return true
         end
         if p:sub(1, 1) == "*" and name:find(vim.pesc(p:sub(2)) .. "$") then
            return true
         end
      end
      return false
   end, { path = path, upward = true })[1]
   return pattern and { vim.fs.dirname(pattern) } or {}
end

function root.bufpath(buf)
   return root.realpath(vim.api.nvim_buf_get_name(assert(buf)))
end

function root.cwd()
   return root.realpath(vim.uv.cwd()) or ""
end

function root.realpath(path)
   if path == "" or path == nil then
      return nil
   end
   path = vim.uv.fs_realpath(path) or path
   return Utils.norm(path)
end

function root.resolve(spec)
   if root.detectors[spec] then
      return root.detectors[spec]
   elseif type(spec) == "function" then
      return spec
   end
   return function(buf)
      return root.detectors.pattern(buf, spec)
   end
end

function root.detect(opts)
   opts = opts or {}
   opts.spec = opts.spec or type(vim.g.root_spec) == "table" and vim.g.root_spec or root.spec
   opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

   local ret = {}
   for _, spec in ipairs(opts.spec) do
      local paths = root.resolve(spec)(opts.buf)
      paths = paths or {}
      paths = type(paths) == "table" and paths or { paths }
      local roots = {} ---@type string[]
      for _, p in ipairs(paths) do
         local pp = root.realpath(p)
         if pp and not vim.tbl_contains(roots, pp) then
            roots[#roots + 1] = pp
         end
      end
      table.sort(roots, function(a, b)
         return #a > #b
      end)
      if #roots > 0 then
         ret[#ret + 1] = { spec = spec, paths = roots }
         if opts.all == false then
            break
         end
      end
   end
   return ret
end

function root.info()
   local spec = type(vim.g.root_spec) == "table" and vim.g.root_spec or root.spec

   local roots = root.detect({ all = true })
   local lines = {} ---@type string[]
   local first = true
   for _, root_local in ipairs(roots) do
      for _, path in ipairs(root_local.paths) do
         lines[#lines + 1] = ("- [%s] `%s` **(%s)**"):format(
            first and "x" or " ",
            path,
            type(root_local.spec) == "table" and table.concat(root_local.spec, ", ") or root_local.spec
         )
         first = false
      end
   end
   lines[#lines + 1] = "```lua"
   lines[#lines + 1] = "vim.g.root_spec = " .. vim.inspect(spec)
   lines[#lines + 1] = "```"
   Utils.notify.info(lines, {})
   return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

root.cache = {}

function root.setup()
   vim.api.nvim_create_user_command("Root", function()
      Utils.root.info()
   end, { desc = "Roots for the current buffer" })

   -- FIX: doesn't properly clear cache in neo-tree `set_root` (which should happen presumably on `DirChanged`),
   -- probably because the event is triggered in the neo-tree buffer, therefore add `BufEnter`
   -- Maybe this is too frequent on `BufEnter` and something else should be done instead??
   vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("root_cache", { clear = true }),
      callback = function(event)
         root.cache[event.buf] = nil
      end,
   })
end

function root.get(opts)
   opts = opts or {}
   local buf = opts.buf or vim.api.nvim_get_current_buf()
   local ret = root.cache[buf]
   if not ret then
      local roots = root.detect({ all = false, buf = buf })
      ret = roots[1] and roots[1].paths[1] or vim.uv.cwd()
      root.cache[buf] = ret
   end
   if opts and opts.normalize then
      return ret
   end
   return ret
end

function root.git()
   local local_root = root.get()
   local git_root = vim.fs.find(".git", { path = local_root, upward = true })[1]
   local ret = git_root and vim.fn.fnamemodify(git_root, ":h") or local_root
   return ret
end

return root
