local version = vim.version()
if vim.fn.has("nvim-0.11") ~= 1 then
  error(
    string.format(
      "This Neovim configuration requires Neovim 0.11.0 or newer (found %d.%d.%d).",
      version.major,
      version.minor,
      version.patch
    )
  )
end

-- Enable the experimental Lua module loader for better startup performance
vim.loader.enable()

require("kostevski").setup()
