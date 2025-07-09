---@class CacheEntry
---@field value any Cached value
---@field timestamp integer Creation timestamp (milliseconds)
---@field hits integer Access count
---@field size? integer Estimated size in bytes

---@class CacheStore
---@field data table<string, CacheEntry> Cache entries
---@field ttl integer Time to live in milliseconds
---@field max_size integer Maximum cache size in bytes
---@field max_entries integer Maximum number of entries
---@field eviction_policy "lru"|"lfu"|"fifo" Eviction policy
---@field stats CacheStats Statistics

---@class CacheStats
---@field hits integer Cache hits
---@field misses integer Cache misses
---@field evictions integer Number of evictions
---@field size integer Current size in bytes

---@alias CacheEvictionPolicy "lru"|"lfu"|"fifo"

---@class CacheOptions
---@field ttl? integer Time to live in milliseconds
---@field max_size? integer Maximum cache size in bytes
---@field max_entries? integer Maximum number of entries
---@field eviction_policy? CacheEvictionPolicy Eviction policy

---@class CacheInterface
---@field get fun(key: string): any? Get value from cache
---@field set fun(key: string, value: any): nil Set value in cache
---@field delete fun(key: string): nil Delete entry from cache
---@field clear fun(pattern?: string): nil Clear cache entries
---@field stats fun(): CacheStats Get cache statistics
---@field get_or_set fun(key: string, compute: fun(): any): any Get or compute value
---@field memoize fun(fn: function, key_fn?: fun(...): string): function Memoize function

---@class UtilsCache Cache utilities
---@field global CacheInterface Global cache instance
---@field lsp CacheInterface LSP cache instance
---@field filesystem CacheInterface Filesystem cache instance
local Cache = {}

-- Cache stores
---@type table<string, CacheStore>
local stores = {}

-- Default configuration
---@type integer
local DEFAULT_TTL = 300000 -- 5 minutes
---@type integer
local DEFAULT_MAX_SIZE = 10 * 1024 * 1024 -- 10MB
---@type integer
local DEFAULT_MAX_ENTRIES = 1000

---Estimate size of a value in bytes
---@param value any Value to estimate
---@return integer size Estimated size in bytes
local function estimate_size(value)
   local t = type(value)
   if t == "string" then
      return #value
   elseif t == "number" then
      return 8
   elseif t == "boolean" then
      return 1
   elseif t == "table" then
      local size = 0
      for k, v in pairs(value) do
         size = size + estimate_size(k) + estimate_size(v)
      end
      return size
   else
      return 64 -- Default size for unknown types
   end
end

---Create interface for a cache store
---@private
---@param name string Store name
---@return CacheInterface cache_interface Cache interface with methods
function Cache._create_interface(name)
   local store = stores[name]
   if not store then
      error(string.format("Cache store '%s' does not exist", name))
   end

   local interface = {}

   ---Get value from cache
   ---@param key string Cache key
   ---@return any? value Cached value or nil if not found/expired
   function interface.get(key)
      vim.validate({ key = { key, "string" } })

      local entry = store.data[key]
      if not entry then
         store.stats.misses = store.stats.misses + 1
         return nil
      end

      -- Check TTL
      if vim.loop.now() - entry.timestamp > store.ttl then
         interface.delete(key)
         store.stats.misses = store.stats.misses + 1
         return nil
      end

      -- Update access info
      entry.hits = entry.hits + 1
      store.stats.hits = store.stats.hits + 1

      return entry.value
   end

   ---Set value in cache
   ---@param key string Cache key
   ---@param value any Value to cache
   function interface.set(key, value)
      vim.validate({ key = { key, "string" } })

      -- Estimate size
      local size = estimate_size(value)

      -- Check if we need to evict
      while store.stats.size + size > store.max_size or vim.tbl_count(store.data) >= store.max_entries do
         interface._evict()
      end

      -- Remove old entry if exists
      if store.data[key] then
         store.stats.size = store.stats.size - (store.data[key].size or 0)
      end

      -- Add new entry
      store.data[key] = {
         value = value,
         timestamp = vim.loop.now(),
         hits = 0,
         size = size,
      }

      store.stats.size = store.stats.size + size
   end

   ---Delete entry from cache
   ---@param key string Cache key to delete
   function interface.delete(key)
      local entry = store.data[key]
      if entry then
         store.stats.size = store.stats.size - (entry.size or 0)
         store.data[key] = nil
      end
   end

   ---Clear cache entries
   ---@param pattern? string Optional Lua pattern to match keys
   function interface.clear(pattern)
      if pattern then
         for key in pairs(store.data) do
            if key:match(pattern) then
               interface.delete(key)
            end
         end
      else
         store.data = {}
         store.stats.size = 0
      end
   end

   ---@class CacheCandidate
   ---@field key string Cache key
   ---@field entry CacheEntry Cache entry
   ---@field score number Eviction score

   ---Evict entries based on policy
   ---@private
   function interface._evict()
      local candidates = {}
      for key, entry in pairs(store.data) do
         table.insert(candidates, {
            key = key,
            entry = entry,
            score = interface._calculate_eviction_score(entry),
         })
      end

      if #candidates == 0 then
         return
      end

      -- Sort by eviction score (lower score = evict first)
      table.sort(candidates, function(a, b)
         return a.score < b.score
      end)

      -- Evict lowest scoring entry
      interface.delete(candidates[1].key)
      store.stats.evictions = store.stats.evictions + 1
   end

   ---Calculate eviction score based on policy
   ---@private
   ---@param entry CacheEntry Entry to score
   ---@return number score Lower score = evict first
   function interface._calculate_eviction_score(entry)
      local policy = store.eviction_policy
      local now = vim.loop.now()

      if policy == "lru" then
         -- Least Recently Used: score by last access time
         return now - entry.timestamp
      elseif policy == "lfu" then
         -- Least Frequently Used: score by hit count
         return entry.hits
      elseif policy == "fifo" then
         -- First In First Out: score by creation time
         return entry.timestamp
      else
         -- Default to LRU
         return now - entry.timestamp
      end
   end

   ---Get cache statistics
   ---@return CacheStats stats Copy of current statistics
   function interface.stats()
      return vim.deepcopy(store.stats)
   end

   ---Get or compute value
   ---@generic T
   ---@param key string Cache key
   ---@param compute fun(): T Function to compute value if not cached
   ---@return T value Cached or computed value
   function interface.get_or_set(key, compute)
      local value = interface.get(key)
      if value ~= nil then
         return value
      end

      value = compute()
      if value ~= nil then
         interface.set(key, value)
      end

      return value
   end

   ---@alias CacheKeyGenerator fun(...): string

   ---Memoize a function
   ---@generic T
   ---@param fn fun(...): T Function to memoize
   ---@param key_fn? CacheKeyGenerator Function to generate cache key from arguments
   ---@return fun(...): T memoized Memoized function
function interface.memoize(fn, key_fn)
   key_fn = key_fn or function(...)
      local args = {...}
      return vim.inspect(args)
   end

   return function(...)
      local args = {...}
      local key = key_fn(unpack(args))
      return interface.get_or_set(key, function()
         return fn(unpack(args))
      end)
   end
end

   return interface
end

---Create a new cache store
---@param name string Store identifier
---@param opts? CacheOptions Configuration options
---@return CacheInterface cache_interface Cache interface with methods
function Cache.create(name, opts)
   vim.validate({
      name = { name, "string" },
      opts = { opts, "table", true },
   })

   -- Return existing store interface if it already exists
   if stores[name] then
      return Cache._create_interface(name)
   end

   opts = opts or {}

   -- Initialize store
   stores[name] = {
      data = {},
      ttl = opts.ttl or DEFAULT_TTL,
      max_size = opts.max_size or DEFAULT_MAX_SIZE,
      max_entries = opts.max_entries or DEFAULT_MAX_ENTRIES,
      eviction_policy = opts.eviction_policy or "lru",
      stats = {
         hits = 0,
         misses = 0,
         evictions = 0,
         size = 0,
      },
   }

   -- Return interface for the new store
   return Cache._create_interface(name)
end

---@class CacheStoreInfo
---@field entries integer Number of entries
---@field stats CacheStats Statistics
---@field ttl integer Time to live
---@field max_size integer Maximum size
---@field max_entries integer Maximum entries

---Get all cache stores information
---@return table<string, CacheStoreInfo> stores Store information by name
function Cache.get_stores()
   local result = {}
   for name, store in pairs(stores) do
      result[name] = {
         entries = vim.tbl_count(store.data),
         stats = vim.deepcopy(store.stats),
         ttl = store.ttl,
         max_size = store.max_size,
         max_entries = store.max_entries,
      }
   end
   return result
end

---Clear all cache stores data
function Cache.clear_all()
   for name, _ in pairs(stores) do
      stores[name].data = {}
      stores[name].stats.size = 0
   end
end

---Delete a cache store completely
---@param name string Store name to delete
function Cache.delete_store(name)
   stores[name] = nil
end

-- Create global caches
Cache.global = Cache.create("global", { ttl = 600000 }) -- 10 minutes
Cache.lsp = Cache.create("lsp", { ttl = 30000 }) -- 30 seconds
Cache.filesystem = Cache.create("filesystem", { ttl = 5000 }) -- 5 seconds

-- Periodic cleanup
---@type uv_timer_t
local cleanup_timer = vim.loop.new_timer()
cleanup_timer:start(
   60000,
   60000,
   vim.schedule_wrap(function()
      for name, store in pairs(stores) do
         local now = vim.loop.now()
         local expired = {}

         for key, entry in pairs(store.data) do
            if now - entry.timestamp > store.ttl then
               table.insert(expired, key)
            end
         end

         -- Clean up expired entries directly
         for _, key in ipairs(expired) do
            if store.data[key] then
               store.stats.size = store.stats.size - (store.data[key].size or 0)
               store.data[key] = nil
            end
         end
      end
   end)
)

return Cache
