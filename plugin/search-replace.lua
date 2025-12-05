-- plugin/search-replace.lua
-- Entry point for search-replace.nvim plugin

-- Prevent loading twice
if vim.g.loaded_search_replace then
  return
end
vim.g.loaded_search_replace = true

-- Check Neovim version
if vim.fn.has("nvim-0.8") ~= 1 then
  vim.notify("search-replace.nvim requires Neovim >= 0.8", vim.log.levels.ERROR)
  return
end

-- Lazy load: setup will be called by user
-- require("search-replace").setup()
