-- tests/minimal_init.lua
local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

-- Add the plugin itself to the runtime path
vim.opt.rtp:append(M.root())

-- Add dependencies (Assumes they are installed in standard locations or vendor them)
-- For this environment, we will try to find them or assume the user has them.
-- A common pattern is to clone them to a 'vendor' directory for testing if not present.
-- Here we will try to use common paths or expect them to be passed in RTP.

-- Example: Add plenary and nui if they exist in a vendor dir
local vendor_paths = {
  M.root("vendor/plenary.nvim"),
  M.root("vendor/nui.nvim"),
}

for _, path in ipairs(vendor_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:append(path)
  end
end

-- Also try to load from standard packpath if not found
vim.cmd([[runtime! plugin/plenary.vim]])
