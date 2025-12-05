-- lua/search-replace/core/platform.lua
-- Cross-platform utilities

local M = {}

---Check if running on Windows
---@return boolean
function M.is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

---Get the path separator for current platform
---@return string
function M.path_sep()
  return M.is_windows() and "\\" or "/"
end

---Normalize path separators for the current platform
---@param path string
---@return string
function M.normalize_path(path)
  if M.is_windows() then
    return path:gsub("/", "\\")
  else
    return path:gsub("\\", "/")
  end
end

---Get the ripgrep executable name
---@return string
function M.rg_executable()
  return "rg"
end

---Build a shell command that works on both Windows and Unix
---@param cwd string Working directory
---@param cmd string Command to run
---@param args string[] Arguments
---@return string
function M.build_command(cwd, cmd, args)
  local escaped_args = vim.tbl_map(vim.fn.shellescape, args)
  local args_str = table.concat(escaped_args, " ")

  if M.is_windows() then
    -- Windows: use cmd /c with pushd
    local escaped_cwd = vim.fn.shellescape(cwd)
    return string.format('cmd /c "pushd %s && %s %s"', escaped_cwd, cmd, args_str)
  else
    -- Unix: use cd &&
    local escaped_cwd = vim.fn.shellescape(cwd)
    return string.format("cd %s && %s %s", escaped_cwd, cmd, args_str)
  end
end

---Execute a command and return output
---@param cwd string Working directory
---@param cmd string Command to run
---@param args string[] Arguments
---@return string[] output, number exit_code
function M.execute(cwd, cmd, args)
  local full_cmd = M.build_command(cwd, cmd, args)
  local output = vim.fn.systemlist(full_cmd)
  local exit_code = vim.v.shell_error
  return output, exit_code
end

return M
