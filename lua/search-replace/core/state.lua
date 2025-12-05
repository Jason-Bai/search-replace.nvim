-- lua/search-replace/core/state.lua
-- State management for search results and selections

---@class SearchResult
---@field file string File path
---@field line_number number Line number
---@field text string Line content

local M = {}

---@type SearchResult[]
local results = {}

---@type table<number, boolean> Set of selected indices
local selected_indices = {}

---Resets the state to initial empty values
function M.reset()
  results = {}
  selected_indices = {}
end

---Sets the search results and selects all by default
---@param items SearchResult[] List of search results
function M.set_results(items)
  results = items
  selected_indices = {}
  -- Default select all
  for i = 1, #items do
    selected_indices[i] = true
  end
end

---Gets all search results
---@return SearchResult[]
function M.get_results()
  return results
end

---Checks if an item at index is selected
---@param index number 1-based index
---@return boolean
function M.is_selected(index)
  return selected_indices[index] == true
end

---Toggles selection of an item at index
---@param index number 1-based index
function M.toggle_selection(index)
  if selected_indices[index] then
    selected_indices[index] = false
  else
    selected_indices[index] = true
  end
end

---Gets only selected items
---@return SearchResult[]
function M.get_selected_items()
  local selected = {}
  for i, item in ipairs(results) do
    if selected_indices[i] then
      table.insert(selected, item)
    end
  end
  return selected
end

return M
