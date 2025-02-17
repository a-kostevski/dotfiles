---@class CacheEntry
---@field value any
---@field timestamp number

---@class CacheStore
---@field data table<string, CacheEntry>
---@field ttl number

---@class CacheStats
---@field entries number
---@field store_name string
---@field ttl number

---@class CacheInterface
---@field get fun(key: string): any|nil
---@field set fun(key: string, value: any): nil
---@field clear fun(pattern?: string): nil
---@field stats fun(): CacheStats

---@class Cache
---@field private stores table<string, CacheStore>
local Cache = {
   stores = {},
}

-- Constants
local DEFAULT_TTL = 30000 -- 30 seconds

---@generic T
---@param name string Store identifier
---@param opts? {ttl: number}
---@return CacheInterface<T>
function Cache.create(name, opts)
   vim.validate({
      name = { name, "string" },
      opts = { opts, "table", true },
   })

   if Cache.stores[name] then
      error(string.format("Cache store '%s' already exists", name))
   end

   opts = opts or {}
   local ttl = opts.ttl or DEFAULT_TTL
   local store = {}

   Cache.stores[name] = {
      data = {},
      ttl = ttl,
   }

   ---@param key string
   ---@return any|nil
   function store.get(key)
      vim.validate({ key = { key, "string" } })

      local cache = Cache.stores[name].data[key]
      if cache and (vim.loop.now() - cache.timestamp) < ttl then
         return cache.value
      end
      Cache.stores[name].data[key] = nil
      return nil
   end

   ---Set a cache value
   ---@param key string
   ---@param value any
   function store.set(key, value)
      vim.validate({ key = { key, "string" } })
      
      local success, err = pcall(function()
         Cache.stores[name].data[key] = {
            value = value,
            timestamp = vim.loop.now(),
         }
      end)
      
      if not success then
         Utils.notify.error(string.format("Failed to cache %s: %s", key, err))
      end
   end

   ---Clear cache entries
   ---@param pattern? string Optional pattern to match keys
   function store.clear(pattern)
      if pattern then
         for key in pairs(Cache.stores[name].data) do
            if key:match(pattern) then
               Cache.stores[name].data[key] = nil
            end
         end
      else
         Cache.stores[name].data = {}
      end
   end

   ---Get cache statistics
   ---@return CacheStats
   function store.stats()
      return {
         entries = vim.tbl_count(Cache.stores[name].data),
         store_name = name,
         ttl = Cache.stores[name].ttl,
      }
   end

   return store
end

function Cache.clear_all()
   Cache.stores = {}
end

return Cache
