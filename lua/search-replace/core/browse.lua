-- lua/search-replace/core/browse.lua
-- Browse Mode: Navigate through search matches in Preview window

local M = {}

-- Namespace for highlight management
local ns_id = vim.api.nvim_create_namespace("search_replace_browse")

-- State (designed for future cross-file navigation in v0.3.0)
local browse_state = {
  active = false,
  current_file_idx = 1, -- Current file in global list (for v0.3.0)
  current_match_idx = 1, -- Current match in current file
  files_list = {}, -- { {file="path", matches={...}}, ... }
  search_pattern = "", -- Current search pattern

  -- Window references
  preview_win = nil,
  results_win = nil,

  -- Saved keymaps (for cleanup)
  saved_keymaps = {},
}

---Helper: Get current match object
---@return table|nil match Current match or nil
local function get_current_match()
  if browse_state.current_file_idx < 1 or browse_state.current_file_idx > #browse_state.files_list then
    return nil
  end

  local current_file = browse_state.files_list[browse_state.current_file_idx]
  if not current_file or not current_file.matches then
    return nil
  end

  if browse_state.current_match_idx < 1 or browse_state.current_match_idx > #current_file.matches then
    return nil
  end

  return current_file.matches[browse_state.current_match_idx]
end

---Helper: Get current file object
---@return table|nil file_group Current file group or nil
local function get_current_file()
  if browse_state.current_file_idx < 1 or browse_state.current_file_idx > #browse_state.files_list then
    return nil
  end
  return browse_state.files_list[browse_state.current_file_idx]
end

---Helper: Highlight current match using namespace
local function highlight_current_match()
  local match = get_current_match()
  if not match or not browse_state.preview_win then
    return
  end

  local bufnr = browse_state.preview_win.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local line_idx = match.line_number - 1 -- 0-indexed

  -- Highlight the entire line with CursorLine (subtle background)
  vim.api.nvim_buf_add_highlight(bufnr, ns_id, "CursorLine", line_idx, 0, -1)

  -- Highlight the search pattern (prominent)
  -- Try to find the pattern in the line
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)
  if #lines > 0 then
    local line_content = lines[1]
    -- Use column info from match if available
    if match.column and match.column > 0 then
      local col_start = match.column - 1 -- 0-indexed
      -- Try to calculate end position based on pattern length
      local pattern_len = #browse_state.search_pattern
      local col_end = col_start + pattern_len

      vim.api.nvim_buf_add_highlight(bufnr, ns_id, "IncSearch", line_idx, col_start, col_end)
    else
      -- Fallback: try to find pattern in line
      local start_pos, end_pos = string.find(line_content, browse_state.search_pattern, 1, true)
      if start_pos then
        vim.api.nvim_buf_add_highlight(
          bufnr,
          ns_id,
          "IncSearch",
          line_idx,
          start_pos - 1, -- 0-indexed
          end_pos
        )
      end
    end
  end
end

---Helper: Update title bar with current position
local function update_title_bar()
  if not browse_state.preview_win or not browse_state.active then
    return
  end

  local current_file = get_current_file()
  if not current_file then
    return
  end

  local match = get_current_match()
  if not match then
    return
  end

  local total_matches = #current_file.matches
  local filename = vim.fn.fnamemodify(current_file.file, ":~:.")

  local title = string.format(
    " Browse [%d/%d] - %s:%d (n:next N:prev q:exit) ",
    browse_state.current_match_idx,
    total_matches,
    filename,
    match.line_number
  )

  -- Update border title (safely)
  if browse_state.preview_win.border and browse_state.preview_win.border.bufnr then
    if vim.api.nvim_buf_is_valid(browse_state.preview_win.border.bufnr) then
      browse_state.preview_win.border:set_text("top", title, "center")
    end
  end
end

---Helper: Jump to current match
local function jump_to_match()
  local match = get_current_match()
  if not match or not browse_state.preview_win then
    return
  end

  local winid = browse_state.preview_win.winid
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  -- Set cursor to match line
  local line_num = match.line_number
  local col = (match.column and match.column > 0) and (match.column - 1) or 0

  -- Make sure line number is valid
  local buf_line_count = vim.api.nvim_buf_line_count(browse_state.preview_win.bufnr)
  if line_num > 0 and line_num <= buf_line_count then
    vim.api.nvim_win_set_cursor(winid, { line_num, col })

    -- Center the window on the match
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_call(winid, function()
          vim.cmd("normal! zz")
        end)
      end
    end)
  end

  highlight_current_match()
  update_title_bar()
end

---Enter browse mode
---@param preview_window table NUI Popup window
---@param results_window table NUI Menu window
---@param file_path string Initial file path
---@param line_number number Initial line number
---@param all_files_data table[] All file groups
---@param search_pattern string Search pattern for highlighting
---@param focus_handlers table? Optional {next=fn, prev=fn} for Tab navigation
function M.enter(preview_window, results_window, file_path, line_number, all_files_data, search_pattern, focus_handlers)
  -- Force cleanup if already active (safety net)
  -- But do minimal cleanup to avoid errors with uninitialized state
  if browse_state.active then
    browse_state.active = false
    -- Clear any existing highlights
    if browse_state.preview_win and browse_state.preview_win.bufnr then
      local bufnr = browse_state.preview_win.bufnr
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
    end
  end

  browse_state.active = true
  browse_state.preview_win = preview_window
  browse_state.results_win = results_window
  browse_state.files_list = all_files_data or {}
  browse_state.search_pattern = search_pattern or ""

  -- Find the file index
  browse_state.current_file_idx = 1
  for i, file_group in ipairs(browse_state.files_list) do
    if file_group.file == file_path then
      browse_state.current_file_idx = i
      break
    end
  end

  -- Find the match index (closest to line_number)
  local current_file = get_current_file()
  if current_file and current_file.matches then
    browse_state.current_match_idx = 1
    for i, match in ipairs(current_file.matches) do
      if match.line_number >= line_number then
        browse_state.current_match_idx = i
        break
      end
    end
  end

  -- Load file content into preview buffer
  if vim.fn.filereadable(file_path) == 1 then
    -- CRITICAL: Ensure buffer is modifiable before writing
    -- (in case user didn't properly exit previous browse mode)
    vim.api.nvim_buf_set_option(preview_window.bufnr, "modifiable", true)

    local file_lines = vim.fn.readfile(file_path)
    vim.api.nvim_buf_set_lines(preview_window.bufnr, 0, -1, false, file_lines)

    -- Set buffer options
    vim.api.nvim_buf_set_option(preview_window.bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(preview_window.bufnr, "buftype", "nofile")

    -- Set filetype for syntax highlighting
    local ext = vim.fn.fnamemodify(file_path, ":e")
    if ext and ext ~= "" then
      local ft_map = {
        tsx = "typescriptreact",
        jsx = "javascriptreact",
        ts = "typescript",
        js = "javascript",
        md = "markdown",
        yml = "yaml",
      }
      local ft = ft_map[ext] or ext
      vim.bo[preview_window.bufnr].filetype = ft
    end
  end

  -- **CRITICAL: Transfer focus to Preview window**
  vim.api.nvim_set_current_win(preview_window.winid)

  -- Jump to match and highlight
  jump_to_match()

  -- Enable n/N/q navigation (buffer-local mappings)
  local map_opts = { buffer = preview_window.bufnr, noremap = true, silent = true }

  vim.keymap.set("n", "n", M.next_match, map_opts)
  vim.keymap.set("n", "N", M.prev_match, map_opts)
  vim.keymap.set("n", "q", M.exit, map_opts)

  -- Override Tab/Shift-Tab to auto-exit Browse Mode before switching focus
  -- This ensures clean state when user navigates away
  if focus_handlers then
    vim.keymap.set("n", "<Tab>", function()
      M.exit()
      if focus_handlers.next then
        focus_handlers.next()
      end
    end, map_opts)

    vim.keymap.set("n", "<S-Tab>", function()
      M.exit()
      if focus_handlers.prev then
        focus_handlers.prev()
      end
    end, map_opts)
  end

  -- Store for cleanup
  browse_state.saved_keymaps = { "n", "N", "q", "<Tab>", "<S-Tab>" }
end

---Move to next match
function M.next_match()
  if not browse_state.active then
    return
  end

  local current_file = get_current_file()
  if not current_file then
    return
  end

  -- Try to move to next match in current file
  if browse_state.current_match_idx < #current_file.matches then
    browse_state.current_match_idx = browse_state.current_match_idx + 1
    jump_to_match()
  else
    -- At last match in current file
    -- v0.2.0: Just notify (no cross-file navigation yet)
    -- v0.3.0: Jump to next file's first match
    vim.notify("Last match in file (use j/k to see other files in Results)", vim.log.levels.INFO)
  end
end

---Move to previous match
function M.prev_match()
  if not browse_state.active then
    return
  end

  local current_file = get_current_file()
  if not current_file then
    return
  end

  -- Try to move to previous match
  if browse_state.current_match_idx > 1 then
    browse_state.current_match_idx = browse_state.current_match_idx - 1
    jump_to_match()
  else
    -- At first match in current file
    vim.notify("First match in file", vim.log.levels.INFO)
  end
end

---Exit browse mode and return to Results
function M.exit()
  if not browse_state.active then
    return
  end

  -- Clear highlights using namespace (clean and efficient)
  if browse_state.preview_win and browse_state.preview_win.bufnr then
    local bufnr = browse_state.preview_win.bufnr
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

      -- Restore buffer to modifiable state for normal preview updates
      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    end
  end

  -- Remove buffer-local keymaps
  if browse_state.preview_win and browse_state.preview_win.bufnr then
    local bufnr = browse_state.preview_win.bufnr
    if vim.api.nvim_buf_is_valid(bufnr) then
      for _, key in ipairs(browse_state.saved_keymaps) do
        pcall(vim.keymap.del, "n", key, { buffer = bufnr })
      end
    end
  end

  -- Restore preview title (safely)
  if browse_state.preview_win and browse_state.preview_win.border and browse_state.preview_win.border.bufnr then
    if vim.api.nvim_buf_is_valid(browse_state.preview_win.border.bufnr) then
      pcall(function()
        browse_state.preview_win.border:set_text("top", " Preview ", "center")
      end)
    end
  end

  -- **CRITICAL: Return focus to Results window**
  if browse_state.results_win and browse_state.results_win.winid then
    if vim.api.nvim_win_is_valid(browse_state.results_win.winid) then
      vim.api.nvim_set_current_win(browse_state.results_win.winid)
    end
  end

  -- Reset state
  browse_state.active = false
  browse_state.files_list = {}
  browse_state.current_file_idx = 1
  browse_state.current_match_idx = 1
  browse_state.search_pattern = ""
  browse_state.saved_keymaps = {}
end

---Check if browse mode is active
---@return boolean
function M.is_active()
  return browse_state.active
end

return M
