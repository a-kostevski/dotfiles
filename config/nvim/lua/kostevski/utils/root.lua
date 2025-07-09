---@module 'kostevski.utils.root'
---@description
--- Advanced project root detection for Neovim
---
--- This module provides sophisticated project root detection with multiple strategies:
--- - LSP workspace folders and root directories
--- - Version control systems (git, svn, hg, etc.)
--- - Build systems (make, cmake, gradle, cargo, etc.)
--- - Configuration files (.editorconfig, package.json, etc.)
--- - Monorepo structures (lerna, nx, pnpm workspaces, etc.)
--- - Filetype-specific patterns
--- - Custom detectors
---
--- Features:
--- - Smart caching with TTL and negative caching
--- - Debounced cache invalidation
--- - Performance metrics tracking
--- - Parallel detection support
--- - Extensible detector system
---
--- Usage:
--- ```lua
--- local root = require("kostevski.utils.root")
---
--- -- Get current project root
--- local project_root = root.get()
---
--- -- Change directory to root
--- root.cd()
---
--- -- Find files relative to root
--- local configs = root.find("*.config.js")
---
--- -- Check if path is inside project
--- if root.is_inside("./src/main.js") then
---   -- Path is inside project root
--- end
---
--- -- Register custom detector
--- root.register_detector("myproject", function(buf)
---   return root.detectors.pattern(buf, ".myproject")
--- end)
--- ```

-- Required dependencies
local Utils = require("kostevski.utils")

---@class Root
---@field spec table Default detection specification
---@field detectors table<string, Detector> Available root detectors
---@field cache table<number, string> Buffer-specific root cache
---@field ft_patterns table<string, string[]> Filetype-specific patterns
---@field vcs_patterns string[] Version control system patterns
---@field build_patterns string[] Build system patterns
---@field config_patterns string[] Configuration file patterns
---@field monorepo_patterns string[] Monorepo marker patterns
local root = setmetatable({}, {
   __call = function(self)
      return self.get()
   end,
})

-- Default detection order: LSP, then common patterns, then cwd
root.spec = { "lsp", "vcs", "build", "config", "cwd" }

---@alias Detector fun(buf?: number): string[]
---@type table<string, Detector>
root.detectors = {}

-- Enhanced cache with TTL and negative caching
---@class RootCache
---@field roots table<number, string> Cached root directories per buffer
---@field negative table<number, boolean> Negative cache for buffers without roots
---@field ttl table<number, number> Time-to-live timestamps
---@field detection_time table<number, number> Time taken for detection (ms)
root.cache = {
   roots = {},
   negative = {},
   ttl = {},
   detection_time = {},
}
root.ft_patterns = {}

-- Cache configuration
local CACHE_TTL = 60 * 1000 -- 60 seconds in milliseconds
local DEBOUNCE_MS = 100 -- Debounce autocmd triggers

-- Common project root patterns
root.vcs_patterns = { ".git", ".svn", ".hg", ".fossil", "_darcs", ".bzr" }
root.build_patterns = {
   -- Build tools
   "Makefile",
   "makefile",
   "GNUmakefile",
   "CMakeLists.txt",
   "cmake",
   "build.gradle",
   "build.gradle.kts",
   "settings.gradle",
   "pom.xml",
   "BUILD",
   "BUILD.bazel",
   "WORKSPACE",
   "meson.build",
   "Cargo.toml",
   "go.mod",
   "package.json",
   "pyproject.toml",
   "setup.py",
   "setup.cfg",
   "Gemfile",
   "mix.exs",
   "rebar.config",
   "project.clj",
   "build.sbt",
   "build.xml",
}
root.config_patterns = {
   ".editorconfig",
   ".prettierrc",
   ".prettierrc.json",
   ".prettierrc.js",
   ".eslintrc",
   ".eslintrc.json",
   ".eslintrc.js",
   "tsconfig.json",
   "jsconfig.json",
   "tslint.json",
   ".stylelintrc",
   "rustfmt.toml",
   ".rustfmt.toml",
   "stylua.toml",
   ".stylua.toml",
   "selene.toml",
   ".selene.toml",
   "pyrightconfig.json",
   "requirements.txt",
   "Pipfile",
   "composer.json",
}
root.monorepo_patterns = {
   "lerna.json",
   "nx.json",
   "pnpm-workspace.yaml",
   "rush.json",
   ".monorepo",
   "workspace.json",
}

---Detector for current working directory
---@return string[] List containing the current working directory
function root.detectors.cwd()
   local cwd = vim.uv.cwd()
   return cwd and { cwd } or {}
end

---Detector for version control systems
---@param buf number Buffer number
---@return string[] List of VCS root directories
function root.detectors.vcs(buf)
   return root.detectors.pattern(buf, root.vcs_patterns)
end

---Detector for build systems
---@param buf number Buffer number
---@return string[] List of build system root directories
function root.detectors.build(buf)
   return root.detectors.pattern(buf, root.build_patterns)
end

---Detector for configuration files
---@param buf number Buffer number
---@return string[] List of config file root directories
function root.detectors.config(buf)
   return root.detectors.pattern(buf, root.config_patterns)
end

---Detector for monorepo structures
---@param buf number Buffer number
---@return string[] List of monorepo root directories
function root.detectors.monorepo(buf)
   return root.detectors.pattern(buf, root.monorepo_patterns)
end

---Detector for LSP workspace folders and root directories
---@param buf number Buffer number
---@return string[] List of LSP root directories
function root.detectors.lsp(buf)
   local bufpath = root.bufpath(buf)
   if not bufpath then
      return {}
   end

   local roots = {}
   local clients = Utils.lsp.get_clients(buf)

   -- Filter out ignored LSP clients
   local ignored = vim.g.root_lsp_ignore or {}
   clients = vim.tbl_filter(function(client)
      return not vim.tbl_contains(ignored, client.name)
   end, clients)

   -- Collect workspace folders and root directories
   for _, client in pairs(clients) do
      -- Add workspace folders
      if client.config and client.config.workspace_folders then
         for _, ws in pairs(client.config.workspace_folders) do
            local path = vim.uri_to_fname(ws.uri)
            if path then
               roots[#roots + 1] = path
            end
         end
      end
      -- Add client root directory
      if client.root_dir then
         roots[#roots + 1] = client.root_dir
      end
   end

   -- Filter and normalize paths
   return vim.tbl_filter(function(path)
      path = Utils.norm(path)
      return path and bufpath:find(path, 1, true) == 1
   end, roots)
end

---Detector for file/directory patterns
---@param buf number Buffer number
---@param patterns string|string[] Pattern(s) to search for
---@return string[] List of directories containing the patterns
function root.detectors.pattern(buf, patterns)
   -- Ensure patterns is a table
   patterns = type(patterns) == "string" and { patterns } or patterns
   if not patterns or #patterns == 0 then
      return {}
   end

   local path = root.bufpath(buf) or vim.uv.cwd()
   if not path then
      return {}
   end

   -- Use vim.fs.find to search upward for patterns
   local found = vim.fs.find(function(name)
      for _, p in ipairs(patterns) do
         -- Exact match
         if name == p then
            return true
         end
         -- Wildcard match (e.g., *.json)
         if p:sub(1, 1) == "*" and name:find(vim.pesc(p:sub(2)) .. "$") then
            return true
         end
      end
      return false
   end, {
      path = path,
      upward = true,
      limit = 1, -- Stop at first match
   })

   -- Return directory containing the found pattern
   if found and found[1] then
      local dir = vim.fs.dirname(found[1])
      return dir and { dir } or {}
   end

   return {}
end

---Get buffer path
---@param buf number Buffer number
---@return string? path Normalized buffer path
function root.bufpath(buf)
   -- Validate input
   if type(buf) ~= "number" then
      error(string.format("root.bufpath: expected number, got %s", type(buf)))
   end

   -- Check if buffer is valid
   if not vim.api.nvim_buf_is_valid(buf) then
      return nil
   end

   local name = vim.api.nvim_buf_get_name(buf)
   if name == "" then
      return nil
   end

   return root.realpath(name)
end

---Get current working directory
---@return string cwd Current working directory (normalized)
function root.cwd()
   local cwd = vim.uv.cwd()
   return cwd and root.realpath(cwd) or ""
end

---Get real path by resolving symlinks
---@param path string? Path to resolve
---@return string? normalized_path Normalized absolute path
function root.realpath(path)
   if not path or path == "" then
      return nil
   end

   -- Try to resolve symlinks
   local realpath = vim.uv.fs_realpath(path)
   if realpath then
      return Utils.norm(realpath)
   end

   -- If resolution fails, just normalize the path
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

-- Initialize default filetype patterns
local function init_ft_patterns()
   -- Python
   root.add_patterns("python", {
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      "Pipfile",
      "poetry.lock",
      "tox.ini",
      ".python-version",
      "pyrightconfig.json",
   })

   -- JavaScript/TypeScript
   root.add_patterns("javascript", { "package.json", "node_modules", ".nvmrc", "yarn.lock", "pnpm-lock.yaml" })
   root.add_patterns("typescript", { "tsconfig.json", "package.json", "node_modules" })
   root.add_patterns("javascriptreact", { "package.json", "node_modules", ".nvmrc" })
   root.add_patterns("typescriptreact", { "tsconfig.json", "package.json", "node_modules" })

   -- Go
   root.add_patterns("go", { "go.mod", "go.sum", "go.work", "Gopkg.lock", "Gopkg.toml" })

   -- Rust
   root.add_patterns("rust", { "Cargo.toml", "Cargo.lock", "rust-project.json" })

   -- Ruby
   root.add_patterns("ruby", { "Gemfile", "Gemfile.lock", ".ruby-version", ".rvmrc", "Rakefile" })

   -- Java
   root.add_patterns("java", { "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", ".project" })

   -- C/C++
   root.add_patterns("c", { "CMakeLists.txt", "Makefile", "configure", "compile_commands.json", ".clang-format" })
   root.add_patterns("cpp", { "CMakeLists.txt", "Makefile", "configure", "compile_commands.json", ".clang-format" })

   -- Lua
   root.add_patterns("lua", { ".luarc.json", ".luarc.jsonc", ".luacheckrc", "selene.toml", "stylua.toml" })

   -- PHP
   root.add_patterns("php", { "composer.json", "composer.lock", ".php-version", "phpunit.xml" })

   -- Elixir
   root.add_patterns("elixir", { "mix.exs", "mix.lock", ".formatter.exs" })

   -- Clojure
   root.add_patterns("clojure", { "project.clj", "deps.edn", "build.boot", "shadow-cljs.edn" })

   -- Scala
   root.add_patterns("scala", { "build.sbt", "build.sc", ".scalafmt.conf" })

   -- Haskell
   root.add_patterns("haskell", { "stack.yaml", "*.cabal", "cabal.project", "package.yaml" })

   -- Swift
   root.add_patterns("swift", { "Package.swift", ".swiftpm", "*.xcodeproj", "*.xcworkspace" })

   -- Kotlin
   root.add_patterns("kotlin", { "build.gradle.kts", "settings.gradle.kts", "gradle.properties" })

   -- Vue
   root.add_patterns("vue", { "vue.config.js", "nuxt.config.js", "nuxt.config.ts" })

   -- Zig
   root.add_patterns("zig", { "build.zig", "build.zig.zon" })

   -- Nim
   root.add_patterns("nim", { "*.nimble", "nim.cfg" })
end

---Get root patterns for a specific filetype
---@param ft string Filetype
---@return string[] patterns
function root.get_patterns(ft)
   return root.ft_patterns[ft] or {}
end

---Detect root directory
---@param opts? table Options for root detection
---@return string[] roots List of detected root directories
function root.detect(opts)
   opts = opts or {}
   opts.spec = opts.spec or type(vim.g.root_spec) == "table" and vim.g.root_spec or root.spec
   opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

   -- Get filetype patterns
   local ft = vim.bo[opts.buf].filetype
   local ft_patterns = root.get_patterns(ft)
   if #ft_patterns > 0 then
      table.insert(opts.spec, 1, ft_patterns)
   end

   local ret = {}
   for _, spec in ipairs(opts.spec) do
      local paths = root.resolve(spec)(opts.buf)
      paths = paths or {}
      paths = type(paths) == "table" and paths or { paths }
      local roots = {} ---@type string[]
      for _, p in ipairs(paths) do
         local pp = type(p) == "string" and root.realpath(p) or nil
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

---Invalidate cache for a buffer
---@param buf number Buffer number
local function invalidate_cache(buf)
   root.cache.roots[buf] = nil
   root.cache.negative[buf] = nil
   root.cache.ttl[buf] = nil
   root.cache.detection_time[buf] = nil
end

---Check if cache is still valid
---@param buf number Buffer number
---@return boolean valid True if cache is still valid
local function is_cache_valid(buf)
   local ttl = root.cache.ttl[buf]
   if not ttl then
      return false
   end
   return vim.uv.now() < ttl
end

---Get root directory
---@param opts? table Options for root detection
---@return string
function root.get(opts)
   opts = opts or {}
   local buf = opts.buf or vim.api.nvim_get_current_buf()

   -- Check cache validity
   if is_cache_valid(buf) then
      -- Return cached root or cwd for negative cache
      if root.cache.negative[buf] then
         return vim.uv.cwd() or ""
      end
      local cached = root.cache.roots[buf]
      if cached then
         return cached
      end
   end

   -- Perform detection with timing
   local start_time = vim.uv.hrtime()
   local roots = root.detect({ all = false, buf = buf })
   local detection_time = (vim.uv.hrtime() - start_time) / 1e6 -- Convert to milliseconds

   -- Cache the result
   local ret = (roots[1] and roots[1].paths[1]) or nil
   if ret then
      root.cache.roots[buf] = ret
      root.cache.negative[buf] = false
   else
      root.cache.negative[buf] = true
      ret = vim.uv.cwd() or ""
   end

   -- Set TTL and detection time
   root.cache.ttl[buf] = vim.uv.now() + CACHE_TTL
   root.cache.detection_time[buf] = detection_time

   return ret
end

---Get git root directory
---@return string? git_root Git root directory
function root.git()
   local current_root = root.get()
   local git_root = vim.fs.find(".git", { path = current_root, upward = true })[1]
   local ret = git_root and vim.fn.fnamemodify(git_root, ":h") or current_root
   return ret
end

---Change directory to project root
---@param opts? table Options: { buf = number, silent = boolean }
---@return string root The root directory changed to
function root.cd(opts)
   opts = opts or {}
   local dir = root.get({ buf = opts.buf })

   if dir and dir ~= "" then
      local ok = pcall(vim.cmd.cd, dir)
      if ok then
         if not opts.silent then
            Utils.notify.info(string.format("Changed directory to: %s", dir), { title = "Root" })
         end
         return dir
      else
         Utils.notify.error(string.format("Failed to change directory to: %s", dir), { title = "Root" })
      end
   end

   return vim.uv.cwd() or ""
end

---Find files relative to project root
---@param pattern string|string[] File pattern(s) to search for
---@param opts? table Options: { buf = number, all = boolean }
---@return string[] paths List of found file paths
function root.find(pattern, opts)
   opts = opts or {}
   local dir = root.get({ buf = opts.buf })

   if not dir or dir == "" then
      return {}
   end

   -- Ensure pattern is a table
   local patterns = type(pattern) == "string" and { pattern } or pattern

   -- Use vim.fs.find with the root directory
   local found = vim.fs.find(patterns, {
      path = dir,
      upward = false,
      limit = opts.all and math.huge or 10,
   })

   return found or {}
end

---Check if a path is inside the project root
---@param path string Path to check
---@param opts? table Options: { buf = number }
---@return boolean is_inside True if path is inside project root
function root.is_inside(path, opts)
   opts = opts or {}
   local dir = root.get({ buf = opts.buf })

   if not dir or dir == "" or not path then
      return false
   end

   -- Normalize paths
   dir = root.realpath(dir)
   path = root.realpath(path)

   if not dir or not path then
      return false
   end

   -- Check if path starts with root directory
   return path:sub(1, #dir) == dir
end

---Register a custom root detector
---@param name string Detector name
---@param detector Detector Detector function
function root.register_detector(name, detector)
   if type(name) ~= "string" or name == "" then
      error("Detector name must be a non-empty string")
   end

   if type(detector) ~= "function" then
      error("Detector must be a function")
   end

   root.detectors[name] = detector
end

---Clear cache for all buffers
function root.clear_cache()
   root.cache = {
      roots = {},
      negative = {},
      ttl = {},
      detection_time = {},
   }
   Utils.notify.info("Root cache cleared", { title = "Root" })
end

---Get cache statistics
---@return table stats Cache statistics
function root.cache_stats()
   local stats = {
      total_entries = vim.tbl_count(root.cache.roots),
      negative_entries = vim.tbl_count(vim.tbl_filter(function(v)
         return v
      end, root.cache.negative)),
      avg_detection_time = 0,
      max_detection_time = 0,
      min_detection_time = math.huge,
   }

   -- Calculate detection time statistics
   local total_time = 0
   local count = 0
   for _, time in pairs(root.cache.detection_time) do
      total_time = total_time + time
      count = count + 1
      stats.max_detection_time = math.max(stats.max_detection_time, time)
      stats.min_detection_time = math.min(stats.min_detection_time, time)
   end

   if count > 0 then
      stats.avg_detection_time = total_time / count
   else
      stats.min_detection_time = 0
   end

   return stats
end

---Get root directory information
---@return table info Root directory information
function root.info()
   local spec = type(vim.g.root_spec) == "table" and vim.g.root_spec or root.spec
   local buf = vim.api.nvim_get_current_buf()

   local roots = root.detect({ all = true })
   local lines = {} ---@type string[]
   local first = true

   -- Add cache information
   if root.cache.detection_time[buf] then
      lines[#lines + 1] = string.format("Detection time: %.2fms", root.cache.detection_time[buf])
      lines[#lines + 1] = ""
   end

   for _, root_info in ipairs(roots) do
      for _, path in ipairs(root_info.paths) do
         lines[#lines + 1] = ("- [%s] `%s` **(%s)**"):format(
            first and "x" or " ",
            path,
            type(root_info.spec) == "table" and table.concat(root_info.spec, ", ") or root_info.spec
         )
         first = false
      end
   end

   -- Add current spec configuration
   lines[#lines + 1] = ""
   lines[#lines + 1] = "Current configuration:"
   lines[#lines + 1] = "```lua"
   lines[#lines + 1] = "vim.g.root_spec = " .. vim.inspect(spec)
   lines[#lines + 1] = "```"

   -- Add cache statistics
   local cache_count = vim.tbl_count(root.cache.roots)
   local negative_count = vim.tbl_count(vim.tbl_filter(function(v)
      return v
   end, root.cache.negative))
   lines[#lines + 1] = ""
   lines[#lines + 1] = string.format("Cache: %d entries, %d negative", cache_count, negative_count)

   Utils.notify.info(lines, { title = "Root Detection" })
   return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

-- Debouncer for cache invalidation
local debounce_timer = nil
local pending_invalidations = {}

---Debounced cache invalidation
---@param buf number Buffer number
local function debounced_invalidate(buf)
   pending_invalidations[buf] = true

   if debounce_timer then
      vim.fn.timer_stop(debounce_timer)
   end

   debounce_timer = vim.fn.timer_start(DEBOUNCE_MS, function()
      for b, _ in pairs(pending_invalidations) do
         invalidate_cache(b)
      end
      pending_invalidations = {}
      debounce_timer = nil
   end)
end

function root.setup(opts)
   -- Initialize filetype patterns
   init_ft_patterns()

   vim.api.nvim_create_user_command("Root", function(_)
      Utils.root.info()
   end, { desc = "Show root directory information" })

   opts = opts or {}

   -- Cache invalidation with debouncing
   vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("root_cache", { clear = true }),
      callback = function(event)
         debounced_invalidate(event.buf)
      end,
   })

   vim.api.nvim_create_user_command("RootPatterns", function()
      local ft = vim.bo.filetype
      local patterns = root.get_patterns(ft)

      -- Handle empty patterns case
      if vim.tbl_isempty(patterns) then
         Utils.notify.info(string.format("No root patterns defined for filetype '%s'", ft), {
            title = "Root Patterns",
         })
         return
      end

      local lines = {
         string.format("Root patterns for filetype '%s':", ft),
         string.rep("-", 40),
      }

      for _, pattern in ipairs(patterns) do
         table.insert(lines, string.format("• %s", pattern))
      end

      table.insert(lines, "")
      table.insert(lines, string.format("Total patterns: %d", #patterns))

      Utils.notify.info(table.concat(lines, "\n"), {
         title = "Root Patterns",
         timeout = 5000, -- 5 second timeout
      })
   end, {
      desc = "Show root patterns for current filetype",
   })

   -- Additional commands
   vim.api.nvim_create_user_command("RootCD", function()
      root.cd()
   end, { desc = "Change directory to project root" })

   vim.api.nvim_create_user_command("RootClearCache", function()
      root.clear_cache()
   end, { desc = "Clear root detection cache" })

   vim.api.nvim_create_user_command("RootCacheStats", function()
      local stats = root.cache_stats()
      local lines = {
         "Root Cache Statistics:",
         string.rep("-", 40),
         string.format("Total entries: %d", stats.total_entries),
         string.format("Negative entries: %d", stats.negative_entries),
         string.format("Avg detection time: %.2fms", stats.avg_detection_time),
         string.format("Min detection time: %.2fms", stats.min_detection_time),
         string.format("Max detection time: %.2fms", stats.max_detection_time),
      }
      Utils.notify.info(table.concat(lines, "\n"), { title = "Root Cache" })
   end, { desc = "Show root cache statistics" })

   -- Telescope integration (if available)
   pcall(function()
      vim.api.nvim_create_user_command("RootFind", function()
         local ok, telescope = pcall(require, "telescope.builtin")
         if ok then
            telescope.find_files({ cwd = root.get() })
         else
            Utils.notify.error("Telescope not found", { title = "Root" })
         end
      end, { desc = "Find files in project root" })

      vim.api.nvim_create_user_command("RootGrep", function()
         local ok, telescope = pcall(require, "telescope.builtin")
         if ok then
            telescope.live_grep({ cwd = root.get() })
         else
            Utils.notify.error("Telescope not found", { title = "Root" })
         end
      end, { desc = "Grep in project root" })
   end)
end

return root
