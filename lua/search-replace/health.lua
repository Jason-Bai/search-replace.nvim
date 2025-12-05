-- lua/search-replace/health.lua
-- Health check for :checkhealth search-replace

local M = {}

function M.check()
  vim.health.start("search-replace.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.8") == 1 then
    vim.health.ok("Neovim >= 0.8")
  else
    vim.health.error("Neovim >= 0.8 required", {
      "Please upgrade Neovim to version 0.8 or later",
    })
  end

  -- Check ripgrep
  if vim.fn.executable("rg") == 1 then
    local handle = io.popen("rg --version 2>&1")
    local version = handle and handle:read("*l") or "unknown"
    if handle then
      handle:close()
    end
    vim.health.ok("ripgrep found: " .. version)
  else
    vim.health.error("ripgrep not found", {
      "Install ripgrep: https://github.com/BurntSushi/ripgrep",
      "macOS: brew install ripgrep",
      "Ubuntu: sudo apt install ripgrep",
      "Windows: scoop install ripgrep",
    })
  end

  -- Check nui.nvim
  local nui_ok, _ = pcall(require, "nui.popup")
  if nui_ok then
    vim.health.ok("nui.nvim installed")
  else
    vim.health.error("nui.nvim not found", {
      "Install nui.nvim: https://github.com/MunifTanjim/nui.nvim",
      "lazy.nvim: { 'MunifTanjim/nui.nvim' }",
    })
  end

  -- Check plenary.nvim
  local plenary_ok, _ = pcall(require, "plenary.job")
  if plenary_ok then
    vim.health.ok("plenary.nvim installed")
  else
    vim.health.error("plenary.nvim not found", {
      "Install plenary.nvim: https://github.com/nvim-lua/plenary.nvim",
      "lazy.nvim: { 'nvim-lua/plenary.nvim' }",
    })
  end

  -- Check nvim-web-devicons (optional)
  local devicons_ok, _ = pcall(require, "nvim-web-devicons")
  if devicons_ok then
    vim.health.ok("nvim-web-devicons installed (file icons enabled)")
  else
    vim.health.info("nvim-web-devicons not found (file icons disabled)", {
      "Optional: Install for file icons",
      "lazy.nvim: { 'nvim-tree/nvim-web-devicons' }",
    })
  end
end

return M
