-- lua/search-replace/core/search_options.lua
-- Manages search options (case sensitivity for search and glob)

local M = {}

-- State for search options (separate for search pattern and glob filter)
local state = {
  search_case_sensitive = true,   -- Default: search pattern is case sensitive
  glob_case_sensitive = true,     -- Default: glob filter is case sensitive
}

---Toggle search case sensitivity
---@return boolean new_state
function M.toggle_search_case()
  state.search_case_sensitive = not state.search_case_sensitive
  return state.search_case_sensitive
end

---Toggle glob case sensitivity
---@return boolean new_state
function M.toggle_glob_case()
  state.glob_case_sensitive = not state.glob_case_sensitive
  return state.glob_case_sensitive
end

---Get current search case sensitivity state
---@return boolean
function M.is_search_case_sensitive()
  return state.search_case_sensitive
end

---Get current glob case sensitivity state
---@return boolean
function M.is_glob_case_sensitive()
  return state.glob_case_sensitive
end

---Get ripgrep arguments for search case sensitivity
---@return table args List of ripgrep arguments
function M.get_rg_args()
  local args = {}
  
  if not state.search_case_sensitive then
    table.insert(args, "-i")  -- ignore case for search
  end
  
  return args
end

---Reset options to defaults
function M.reset()
  state.search_case_sensitive = true
  state.glob_case_sensitive = true
end

---Get formatted status string for Search field
---@return string
function M.get_search_status_text()
  local icon = state.search_case_sensitive and "Aa" or "aa"
  return string.format("C-i:%s", icon)
end

---Get formatted status string for Flags field
---@return string
function M.get_glob_status_text()
  local icon = state.glob_case_sensitive and "Aa" or "aa"
  return string.format("C-i:%s", icon)
end

return M

