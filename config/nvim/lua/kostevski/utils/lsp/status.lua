local M = {}

M.active_clients = {}

function M.update_status(client, buf)
   M.active_clients[client.id] = {
      name = client.name,
      buffer = buf,
      status = "active"
   }
end

function M.get_active_servers()
   local result = {}
   for _, client in pairs(M.active_clients) do
      table.insert(result, {
         name = client.name,
         status = client.status
      })
   end
   return result
end

return M 