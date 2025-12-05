-- lua/search-replace/core/diff.lua
local M = {}

---Generates diff lines for preview
---@param original string
---@param replacement string
---@return table List of strings
function M.generate_diff(original, replacement)
  local lines = {}

  -- Simple line-based diff for now
  -- In a real scenario, we might want to highlight specific changes within the line
  -- But for the preview window as described in PRD:
  -- - 11 |   local val = my_old_variable
  -- + 11 |   local val = my_new_variable

  table.insert(lines, "- " .. original)
  table.insert(lines, "+ " .. replacement)

  return lines
end

return M
