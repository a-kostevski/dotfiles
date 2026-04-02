return {
  "nvim-lualine/lualine.nvim",
  init = function()
    vim.g.lualine_laststatus = vim.o.laststatus
    if vim.fn.argc(-1) > 0 then
      vim.o.statusline = " "
    else
      vim.o.laststatus = 0
    end
  end,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function()
    vim.o.laststatus = vim.g.lualine_laststatus

    -- Event-driven LSP progress tracking
    local progress_items = {}
    local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

    vim.api.nvim_create_autocmd("LspProgress", {
      group = vim.api.nvim_create_augroup("kostevski_lualine_progress", { clear = true }),
      callback = function(ev)
        local data = ev.data
        if not (data and data.params) then
          return
        end
        local value = data.params.value
        local token = data.params.token
        if not (value and token) then
          return
        end

        local key = string.format("%d:%s", data.client_id, token)

        if value.kind == "begin" then
          local client = vim.lsp.get_client_by_id(data.client_id)
          progress_items[key] = {
            client_name = client and client.name or "LSP",
            title = value.title,
            message = value.message,
            percentage = value.percentage,
            start_time = vim.uv.now(),
          }
        elseif value.kind == "report" then
          local item = progress_items[key]
          if item then
            item.message = value.message or item.message
            item.percentage = value.percentage or item.percentage
          end
        elseif value.kind == "end" then
          progress_items[key] = nil
        end

        vim.schedule(function()
          vim.cmd.redrawstatus()
        end)
      end,
    })

    local function lsp_progress()
      local item
      for _, v in pairs(progress_items) do
        if not item or v.start_time > item.start_time then
          item = v
        end
      end
      if not item then
        return ""
      end

      local ms = vim.uv.now() - item.start_time
      local frame = math.floor(ms / 120) % #spinner_frames + 1
      local text = item.title or "Loading"
      if item.percentage then
        text = string.format("%s %d%%%%", text, item.percentage)
      end
      return string.format("%s %s", spinner_frames[frame], text)
    end

    local opts = {
      options = {
        theme = "auto",
        globalstatus = vim.o.laststatus == 3,
        disabled_filetypes = {
          statusline = { "ministarter" },
        },
      },
      sections = {
        lualine_c = {
          { "filename" },
          { lsp_progress },
          {
            function()
              return "Recording @" .. vim.fn.reg_recording()
            end,
            cond = function()
              return vim.fn.reg_recording() ~= ""
            end,
          },
        },
      },
      extensions = { "neo-tree" },
    }
    return opts
  end,
}
