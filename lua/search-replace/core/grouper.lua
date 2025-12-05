-- lua/search-replace/core/grouper.lua
-- Groups search results by file

---@class FileGroup
---@field file string File path
---@field match_count number Number of matches in this file
---@field matches SearchMatch[] List of matches in this file

local M = {}

---Groups search results by file and returns summary
---@param items SearchMatch[] List of search matches
---@return FileGroup[] List of file groups
function M.group_by_file(items)
  local file_map = {}
  local files_order = {}

  -- Group matches by file
  for _, item in ipairs(items) do
    if not file_map[item.file] then
      file_map[item.file] = {
        file = item.file,
        match_count = 0,
        matches = {},
      }
      table.insert(files_order, item.file)
    end

    file_map[item.file].match_count = file_map[item.file].match_count + 1
    table.insert(file_map[item.file].matches, item)
  end

  -- Build result in original order
  local result = {}
  for _, file in ipairs(files_order) do
    table.insert(result, file_map[file])
  end

  return result
end

return M
