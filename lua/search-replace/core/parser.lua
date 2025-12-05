-- lua/search-replace/core/parser.lua
-- Parses ripgrep JSON output

---@class SearchMatch
---@field file string File path
---@field line_number number Line number in file
---@field text string Matched line text
---@field match string The matched substring
---@field start_col number Start column of match
---@field end_col number End column of match

local M = {}

---Parses a single line of ripgrep JSON output
---@param line string Raw JSON line from ripgrep
---@return SearchMatch|nil Parsed match or nil if not a match
function M.parse_line(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok or not decoded then
    return nil
  end

  if decoded.type == "match" then
    local data = decoded.data
    local submatch = data.submatches[1]
    return {
      file = data.path.text,
      line_number = data.line_number,
      text = data.lines.text:gsub("\n$", ""), -- Remove trailing newline
      match = submatch.match.text,
      start_col = submatch.start,
      end_col = submatch["end"],
    }
  end

  return nil
end

return M
