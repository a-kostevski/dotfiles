local plug = {}

function plug.is_loaded(name)
   local Config = require("lazy.core.config")
   return Config.plugins[name] and Config.plugins[name]._.loaded
end

function plug.on_load(name, fn)
   if plug.is_loaded(name) then
      fn(name)
   else
      vim.api.nvim_create_autocmd("User", {
         pattern = "LazyLoad",
         callback = function(event)
            if event.data == name then
               fn(name)
               return true
            end
         end,
      })
   end
end

function plug.get_plugin(name)
   return require("lazy.core.config").spec.plugins[name]
end

function plug.opts(name)
   local plugin = plug.get_plugin(name)
   if not plugin then
      return {}
   end

   return require("lazy.core.plugin").values(plugin, "opts", false)
end

function plug.has(name)
   return plug.get_plugin(name) ~= nil
end

return plug
