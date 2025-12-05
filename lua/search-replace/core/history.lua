-- lua/search-replace/core/history.lua
-- Search and replace history management

local Config = require("search-replace.config")

local M = {}

---@class HistoryData
---@field search string[] Search pattern history
---@field replace string[] Replace pattern history

---@type HistoryData
local history = {
  search = {},
  replace = {},
}

---Current indices for navigation
---@type number
local search_index = 0
local replace_index = 0

---Get the history file path
---@return string
local function get_history_path()
  return vim.fn.stdpath("data") .. "/search_replace_history.json"
end

---Load history from file
function M.load()
  local path = get_history_path()
  if vim.fn.filereadable(path) == 1 then
    local content = table.concat(vim.fn.readfile(path), "\n")
    local ok, data = pcall(vim.json.decode, content)
    if ok and data then
      history.search = data.search or {}
      history.replace = data.replace or {}
    end
  end
end

---Save history to file
function M.save()
  local path = get_history_path()
  local ok, content = pcall(vim.json.encode, history)
  if ok then
    vim.fn.writefile({ content }, path)
  end
end

---Add a search pattern to history
---@param pattern string
function M.add_search(pattern)
  if not pattern or pattern == "" then
    return
  end

  local config = Config.get("history")
  if not config or not config.enabled then
    return
  end

  -- Remove if already exists (to move to front)
  for i, p in ipairs(history.search) do
    if p == pattern then
      table.remove(history.search, i)
      break
    end
  end

  -- Add to front
  table.insert(history.search, 1, pattern)

  -- Trim to max entries
  local max = config.max_entries or 50
  while #history.search > max do
    table.remove(history.search)
  end

  -- Reset index
  search_index = 0

  M.save()
end

---Add a replace pattern to history
---@param pattern string
function M.add_replace(pattern)
  if not pattern or pattern == "" then
    return
  end

  local config = Config.get("history")
  if not config or not config.enabled then
    return
  end

  -- Remove if already exists
  for i, p in ipairs(history.replace) do
    if p == pattern then
      table.remove(history.replace, i)
      break
    end
  end

  -- Add to front
  table.insert(history.replace, 1, pattern)

  -- Trim to max entries
  local max = config.max_entries or 50
  while #history.replace > max do
    table.remove(history.replace)
  end

  -- Reset index
  replace_index = 0

  M.save()
end

---Get previous search pattern
---@return string|nil
function M.prev_search()
  if #history.search == 0 then
    return nil
  end

  search_index = math.min(search_index + 1, #history.search)
  return history.search[search_index]
end

---Get next search pattern
---@return string|nil
function M.next_search()
  if #history.search == 0 or search_index <= 0 then
    search_index = 0
    return nil
  end

  search_index = search_index - 1
  if search_index == 0 then
    return ""
  end
  return history.search[search_index]
end

---Get previous replace pattern
---@return string|nil
function M.prev_replace()
  if #history.replace == 0 then
    return nil
  end

  replace_index = math.min(replace_index + 1, #history.replace)
  return history.replace[replace_index]
end

---Get next replace pattern
---@return string|nil
function M.next_replace()
  if #history.replace == 0 or replace_index <= 0 then
    replace_index = 0
    return nil
  end

  replace_index = replace_index - 1
  if replace_index == 0 then
    return ""
  end
  return history.replace[replace_index]
end

---Reset navigation indices
function M.reset_indices()
  search_index = 0
  replace_index = 0
end

---Get search history list
---@return string[]
function M.get_search_history()
  return history.search
end

---Get replace history list
---@return string[]
function M.get_replace_history()
  return history.replace
end

-- Load history on module load
M.load()

return M
