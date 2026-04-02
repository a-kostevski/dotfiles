---@module 'kostevski.utils.root'
--- Project root detection wrapping vim.fs.root() and LSP workspace info.

local Utils = require("kostevski.utils")

---@class Root
local root = setmetatable({}, {
  __call = function(self)
    return self.get()
  end,
})

root.ft_patterns = {}

---@type table<number, string>
local cache = {}

---Add root patterns for a specific filetype
---@param ft string Filetype
---@param patterns string|string[] Patterns to add
function root.add_patterns(ft, patterns)
  if type(patterns) == "string" then
    patterns = { patterns }
  end
  root.ft_patterns[ft] = root.ft_patterns[ft] or {}
  vim.list_extend(root.ft_patterns[ft], patterns)
end

---Get root patterns for a specific filetype
---@param ft string Filetype
---@return string[] patterns
function root.get_patterns(ft)
  return root.ft_patterns[ft] or {}
end

---Get buffer path
---@param buf number Buffer number
---@return string? path
local function bufpath(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  return Utils.norm(vim.uv.fs_realpath(name) or name)
end

---Try to detect root via LSP workspace folders
---@param buf number
---@return string?
local function lsp_root(buf)
  local path = bufpath(buf)
  if not path then
    return nil
  end

  local clients = vim.lsp.get_clients({ bufnr = buf })
  local ignored = vim.g.root_lsp_ignore or {}

  local best
  local best_len = 0

  for _, client in ipairs(clients) do
    if not vim.tbl_contains(ignored, client.name) then
      -- Check workspace folders
      if client.config and client.config.workspace_folders then
        for _, ws in pairs(client.config.workspace_folders) do
          local ws_path = Utils.norm(vim.uri_to_fname(ws.uri))
          if ws_path and path:find(ws_path, 1, true) == 1 and #ws_path > best_len then
            best = ws_path
            best_len = #ws_path
          end
        end
      end
      -- Check root_dir
      if client.root_dir then
        local rd = Utils.norm(client.root_dir)
        if rd and path:find(rd, 1, true) == 1 and #rd > best_len then
          best = rd
          best_len = #rd
        end
      end
    end
  end

  return best
end

---Get project root for the current or specified buffer
---@param opts? { buf?: number }
---@return string
function root.get(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()

  if cache[buf] then
    return cache[buf]
  end

  -- 1. Try LSP root
  local result = lsp_root(buf)

  -- 2. Try filetype-specific patterns via vim.fs.root
  if not result then
    local ft = vim.bo[buf].filetype
    local ft_pats = root.get_patterns(ft)
    if #ft_pats > 0 then
      result = vim.fs.root(buf, ft_pats)
    end
  end

  -- 3. Try VCS markers
  if not result then
    result = vim.fs.root(buf, { ".git", ".svn", ".hg" })
  end

  -- 4. Fallback to cwd
  result = result or vim.uv.cwd() or ""
  cache[buf] = result
  return result
end

---Get git root directory
---@return string?
function root.git()
  local current_root = root.get()
  local git_root = vim.fs.find(".git", { path = current_root, upward = true })[1]
  return git_root and vim.fn.fnamemodify(git_root, ":h") or current_root
end

---Change directory to project root
---@param opts? { buf?: number, silent?: boolean }
function root.cd(opts)
  opts = opts or {}
  local dir = root.get({ buf = opts.buf })
  if dir and dir ~= "" then
    vim.cmd.cd(dir)
    if not opts.silent then
      Utils.notify.info(string.format("Changed directory to: %s", dir), { title = "Root" })
    end
  end
end

---Clear the root cache
function root.clear_cache()
  cache = {}
end

function root.setup()
  -- Invalidate cache on relevant events
  vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged" }, {
    group = vim.api.nvim_create_augroup("root_cache", { clear = true }),
    callback = function(event)
      cache[event.buf] = nil
    end,
  })

  vim.api.nvim_create_user_command("Root", function()
    Utils.notify.info(string.format("Root: %s", root.get()), { title = "Root" })
  end, { desc = "Show root directory" })

  vim.api.nvim_create_user_command("RootCD", function()
    root.cd()
  end, { desc = "Change directory to project root" })
end

return root
