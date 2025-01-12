---@class Root
---@field spec table
---@field detectors table
---@field cache table
local root = setmetatable({}, {
   __call = function(self)
      return self.get()
   end,
})

root.spec = { "lsp", { ".git", "lua" }, "cwd" }
root.detectors = {}
root.cache = {}

---Detector for cwd
---@return table
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
      if client.config and client.config.workspace_folders then
         for _, ws in pairs(client.config.workspace_folders) do
            roots[#roots + 1] = vim.uri_to_fname(ws.uri)
         end
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

---Get buffer path
---@param buf number Buffer number
---@return string? path Normalized buffer path
function root.bufpath(buf)
   return root.realpath(vim.api.nvim_buf_get_name(assert(buf)))
end

---@return string
function root.cwd()
   return root.realpath(vim.uv.cwd()) or ""
end

---Get real path by resolving symlinks
---@param path string? Path to resolve
---@return string? normalized_path Normalized absolute path
function root.realpath(path)
   if path == nil or path == "" then
      return nil
   end
   path = vim.uv.fs_realpath(path) or path
   return Utils.norm(path)
end

---@param spec string|string[]|function Detection specification
---@return function detector Root detector function
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

---Detect root directory
---@param opts? table Options for root detection
---@return string[] roots List of detected root directories
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

---Get root directory
---@param opts? table Options for root detection
---@return string
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

---Get git root directory
---@return string? git_root Git root directory
function root.git()
   local root = root.get()
   local git_root = vim.fs.find(".git", { path = root, upward = true })[1]
   local ret = git_root and vim.fn.fnamemodify(git_root, ":h") or root
   return ret
end

---Get root directory information
---@return table info Root directory information
function root.info()
   local spec = type(vim.g.root_spec) == "table" and vim.g.root_spec or root.spec

   local roots = root.detect({ all = true })
   local lines = {} ---@type string[]
   local first = true
   for _, root in ipairs(roots) do
      for _, path in ipairs(root.paths) do
         lines[#lines + 1] = ("- [%s] `%s` **(%s)**"):format(
            first and "x" or " ",
            path,
            type(root.spec) == "table" and table.concat(root.spec, ", ") or root.spec
         )
         first = false
      end
   end
   lines[#lines + 1] = "```lua"
   lines[#lines + 1] = "vim.g.root_spec = " .. vim.inspect(spec)
   lines[#lines + 1] = "```"
   Utils.notify.info(lines, { title = "Roots" })
   return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

function root.setup(opts)
   vim.api.nvim_create_user_command("Root", function(_)
      Utils.root.info()
   end, { desc = "Root info" })
   opts = opts or {}

   vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("root_cache", { clear = true }),
      callback = function(event)
         root.cache[event.buf] = nil
      end,
   })
end

return root
