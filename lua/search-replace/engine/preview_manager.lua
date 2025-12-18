-- lua/search-replace/engine/preview_manager.lua
-- Manages preview generation and replacement visualization

local Config = require("search-replace.config")
local SearchOptions = require("search-replace.core.search_options")

local M = {}

---@class PreviewManager
---@field preview table NUI Popup component
---@field grouped_files table List of grouped file results
---@field inputs table Input components (search, replace, flags)
---@field replacement_cache table Cache for batch replacement results
local PreviewManager = {}
PreviewManager.__index = PreviewManager

---Create a new PreviewManager instance
---@param preview table NUI Popup component
---@param inputs table Input components table
---@return PreviewManager
function M.new(preview, inputs)
  local self = setmetatable({}, PreviewManager)
  self.preview = preview
  self.inputs = inputs
  self.grouped_files = {}
  self.replacement_cache = {}  -- Cache for batch replacements
  return self
end

---Set the grouped files data
---@param grouped_files table List of grouped file results
function PreviewManager:set_grouped_files(grouped_files)
  self.grouped_files = grouped_files
end

---Get search and replace patterns from input fields
---@return string search_pat Search pattern
---@return string replace_pat Replace pattern
function PreviewManager:get_patterns()
  local search_pat = ""
  if self.inputs.search.bufnr then
    local lines = vim.api.nvim_buf_get_lines(self.inputs.search.bufnr, 0, 1, false)
    if #lines > 0 then
      search_pat = lines[1]:gsub("^> %s*", "")
    end
  end

  local replace_pat = ""
  if self.inputs.replace.bufnr then
    local lines = vim.api.nvim_buf_get_lines(self.inputs.replace.bufnr, 0, 1, false)
    if #lines > 0 then
      replace_pat = lines[1]:gsub("^> %s*", "")
    end
  end

  return search_pat, replace_pat
end

---Escape string for shell command
---@param str string String to escape
---@return string escaped Escaped string
local function escape_for_shell(str)
  return str:gsub("'", "'\\''")
end

---Apply replacement to a single line using perl
---@param original_line string Original line content
---@param search_pat string Search pattern
---@param replace_pat string Replacement pattern
---@return string replaced Replaced line content
function PreviewManager:apply_replacement(original_line, search_pat, replace_pat)
  -- Escape single quotes in the line and patterns for shell
  local escaped_line = escape_for_shell(original_line)
  local escaped_search = escape_for_shell(search_pat)
  local escaped_replace = escape_for_shell(replace_pat)

  -- Use perl with single quotes to preserve $1, $2 etc.
  -- Use /gi when case-insensitive, /g when case-sensitive
  local perl_flags = SearchOptions.is_search_case_sensitive() and "g" or "gi"
  local cmd = string.format(
    "echo '%s' | perl -pe 's/%s/%s/%s' 2>/dev/null",
    escaped_line,
    escaped_search,
    escaped_replace,
    perl_flags
  )

  local result = vim.fn.system(cmd)
  if vim.v.shell_error == 0 and result then
    -- Remove trailing newline
    return result:gsub("\n$", "")
  else
    -- Fallback: return original line with replacement hint
    return original_line .. " → [regex error]"
  end
end

---Apply replacement to entire file at once (OPTIMIZED for batch processing)
---@param file_lines table Array of all file lines
---@param search_pat string Search pattern
---@param replace_pat string Replacement pattern
---@return table replaced_lines Array of replaced lines
function PreviewManager:apply_replacement_batch(file_lines, search_pat, replace_pat)
  -- Join all lines into single string
  local content = table.concat(file_lines, "\n")

  -- Escape for shell
  local escaped_content = escape_for_shell(content)
  local escaped_search = escape_for_shell(search_pat)
  local escaped_replace = escape_for_shell(replace_pat)

  -- Use perl for batch replacement
  local perl_flags = SearchOptions.is_search_case_sensitive() and "g" or "gi"
  local cmd = string.format(
    "echo '%s' | perl -pe 's/%s/%s/%s' 2>/dev/null",
    escaped_content,
    escaped_search,
    escaped_replace,
    perl_flags
  )

  local result = vim.fn.system(cmd)
  if vim.v.shell_error == 0 and result then
    -- Split back into lines
    return vim.split(result, "\n", { plain = true })
  else
    -- Fallback: return original lines
    return file_lines
  end
end

---Get or compute batch replacement with caching
---@param file_path string File path for cache key
---@param file_lines table Array of file lines
---@param search_pat string Search pattern
---@param replace_pat string Replacement pattern
---@return table replaced_lines Array of replaced lines
function PreviewManager:get_replaced_lines_cached(file_path, file_lines, search_pat, replace_pat)
  -- Generate cache key
  local cache_key = string.format("%s|%s|%s|%d",
    file_path,
    search_pat,
    replace_pat,
    #file_lines
  )

  -- Check cache
  if self.replacement_cache[cache_key] then
    return self.replacement_cache[cache_key]
  end

  -- Cache miss: perform batch replacement
  local replaced = self:apply_replacement_batch(file_lines, search_pat, replace_pat)

  -- Store in cache
  self.replacement_cache[cache_key] = replaced

  return replaced
end

---Clear replacement cache (call when search/replace patterns change)
function PreviewManager:clear_cache()
  self.replacement_cache = {}
end

---Update preview for the currently selected file in results
---@param results table NUI Menu component
---@param browse_is_active function Function to check if browse mode is active
function PreviewManager:update_preview(results, browse_is_active)
  -- Don't update preview if Browse Mode is active
  if browse_is_active() then
    return
  end

  local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]

  -- Get the file at this line
  if line_idx > #self.grouped_files then
    vim.api.nvim_buf_set_lines(self.preview.bufnr, 0, -1, false, {})
    return
  end

  local file_group = self.grouped_files[line_idx]
  if not file_group then
    vim.api.nvim_buf_set_lines(self.preview.bufnr, 0, -1, false, {})
    return
  end

  -- Get search and replace patterns
  local search_pat, replace_pat = self:get_patterns()

  -- Read file content
  local file_path = file_group.file
  local file_lines = {}
  if vim.fn.filereadable(file_path) == 1 then
    file_lines = vim.fn.readfile(file_path)
  end

  local preview_lines = {}
  table.insert(preview_lines, "File: " .. file_path)
  table.insert(preview_lines, "Matches: " .. #file_group.matches)
  table.insert(preview_lines, "")

  -- OPTIMIZATION: Batch replacement for all lines at once (if replacement pattern exists)
  local replaced_lines = nil
  if replace_pat ~= "" then
    replaced_lines = self:get_replaced_lines_cached(file_path, file_lines, search_pat, replace_pat)
  end

  -- Show all matches for this file
  for i, match in ipairs(file_group.matches) do
    local line_num = match.line_number
    local original_line = file_lines[line_num] or ""

    table.insert(preview_lines, "--- Match " .. i .. " @ Line " .. line_num .. " ---")

    -- If no replacement pattern, just show context
    if replace_pat == "" then
      -- Show 3 lines of context before and after
      local start_line = math.max(1, line_num - 3)
      local end_line = math.min(#file_lines, line_num + 3)

      for j = start_line, end_line do
        local prefix = j == line_num and ">>> " or "    "
        table.insert(preview_lines, prefix .. file_lines[j])
      end
    else
      -- Show diff for replacement WITH context
      -- OPTIMIZED: Use pre-computed batch replacement result
      local new_line = replaced_lines[line_num] or original_line

      -- Show 3 lines before
      local start_line = math.max(1, line_num - 3)
      for j = start_line, line_num - 1 do
        table.insert(preview_lines, "  " .. file_lines[j])
      end

      -- Show diff
      table.insert(preview_lines, "- " .. original_line)
      table.insert(preview_lines, "+ " .. new_line)

      -- Show 3 lines after
      local end_line = math.min(#file_lines, line_num + 3)
      for j = line_num + 1, end_line do
        table.insert(preview_lines, "  " .. file_lines[j])
      end
    end

    table.insert(preview_lines, "")
  end

  vim.api.nvim_buf_set_lines(self.preview.bufnr, 0, -1, false, preview_lines)

  -- Set buffer filetype for syntax highlighting
  local ext = vim.fn.fnamemodify(file_path, ":e")
  if ext and ext ~= "" then
    -- Map common extensions to filetypes
    local ft_map = {
      tsx = "typescriptreact",
      jsx = "javascriptreact",
      ts = "typescript",
      js = "javascript",
      md = "markdown",
      yml = "yaml",
      py = "python",
      rb = "ruby",
      rs = "rust",
      go = "go",
      c = "c",
      cpp = "cpp",
      h = "c",
      hpp = "cpp",
    }
    local ft = ft_map[ext] or ext
    vim.bo[self.preview.bufnr].filetype = ft

    -- Disable conceal to show "-" and "+" literally (not as list bullets)
    if self.preview.winid and vim.api.nvim_win_is_valid(self.preview.winid) then
      vim.wo[self.preview.winid].conceallevel = 0
    end
  end

  -- Apply highlights to preview lines (diff markers)
  local highlights = Config.get("highlights")
  if highlights then
    for i, line in ipairs(preview_lines) do
      local line_idx = i - 1 -- 0-indexed
      if line:match("^%- ") then
        vim.api.nvim_buf_add_highlight(self.preview.bufnr, -1, highlights.preview_del, line_idx, 0, -1)
      elseif line:match("^%+ ") then
        vim.api.nvim_buf_add_highlight(self.preview.bufnr, -1, highlights.preview_add, line_idx, 0, -1)
      end
    end
  end

  -- Reset cursor to top of preview
  if self.preview.winid and vim.api.nvim_win_is_valid(self.preview.winid) then
    vim.api.nvim_win_set_cursor(self.preview.winid, { 1, 0 })
  end
end

return M
