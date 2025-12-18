-- lua/search-replace/engine/replacement_engine.lua
-- Handles file replacement operations with backup/restore support

local SearchOptions = require("search-replace.core.search_options")
local Job = require("plenary.job")

local M = {}

---@class ReplacementEngine
---@field last_backup table Backup storage for undo functionality
local ReplacementEngine = {}
ReplacementEngine.__index = ReplacementEngine

---Create a new ReplacementEngine instance
---@return ReplacementEngine
function M.new()
  local self = setmetatable({}, ReplacementEngine)
  self.last_backup = {}
  return self
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
function ReplacementEngine:apply_replacement(original_line, search_pat, replace_pat)
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

---Execute replacements on selected files
---@param selected_files table List of file groups to process
---@param search_pat string Search pattern
---@param replace_pat string Replacement pattern
---@return table result { files_modified, matches_replaced, errors }
function ReplacementEngine:execute_replacements(selected_files, search_pat, replace_pat)
  local files_modified = 0
  local matches_replaced = 0
  local errors = {}

  -- Clear previous backup
  self.last_backup = {}

  for _, file_group in ipairs(selected_files) do
    local file_path = file_group.file
    if vim.fn.filereadable(file_path) == 1 then
      -- Check if file is writable
      if vim.fn.filewritable(file_path) ~= 1 then
        table.insert(errors, "Permission denied: " .. file_path)
      else
        local file_lines = vim.fn.readfile(file_path)

        -- Backup original content
        self.last_backup[file_path] = vim.deepcopy(file_lines)

        local modified = false

        for _, match in ipairs(file_group.matches) do
          local line_idx = match.line_number
          local original_line = file_lines[line_idx] or ""
          local new_line = self:apply_replacement(original_line, search_pat, replace_pat)
          if new_line ~= original_line then
            file_lines[line_idx] = new_line
            modified = true
            matches_replaced = matches_replaced + 1
          end
        end

        if modified then
          local write_ok = pcall(vim.fn.writefile, file_lines, file_path)
          if write_ok then
            files_modified = files_modified + 1
          else
            table.insert(errors, "Failed to write: " .. file_path)
            -- Restore backup for this file if write failed
            self.last_backup[file_path] = nil
          end
        else
          -- No changes made, remove from backup
          self.last_backup[file_path] = nil
        end
      end
    else
      table.insert(errors, "File not found: " .. file_path)
    end
  end

  return {
    files_modified = files_modified,
    matches_replaced = matches_replaced,
    errors = errors,
  }
end

---Execute replacements on selected files in parallel (OPTIMIZED)
---@param selected_files table List of file groups to process
---@param search_pat string Search pattern
---@param replace_pat string Replacement pattern
---@param opts? table Options { max_concurrent, show_progress, progress_callback }
---@return table result { files_modified, matches_replaced, errors }
function ReplacementEngine:execute_replacements_parallel(selected_files, search_pat, replace_pat, opts)
  opts = opts or {}
  local max_concurrent = opts.max_concurrent or 20
  local show_progress = opts.show_progress
  local progress_callback = opts.progress_callback

  -- Clear previous backup
  self.last_backup = {}

  -- Step 1: Backup all files first (must be synchronous)
  local backup_errors = {}
  for _, file_group in ipairs(selected_files) do
    local file_path = file_group.file
    if vim.fn.filereadable(file_path) == 1 and vim.fn.filewritable(file_path) == 1 then
      local file_lines = vim.fn.readfile(file_path)
      self.last_backup[file_path] = vim.deepcopy(file_lines)
    else
      table.insert(backup_errors, file_path)
    end
  end

  -- Step 2: Process files in parallel using plenary.job
  local results = {
    files_modified = 0,
    matches_replaced = 0,
    errors = vim.list_extend({}, backup_errors),
    total = #selected_files,
    processed = 0,
  }

  local jobs = {}
  local active_jobs = 0
  local pending_files = vim.list_extend({}, selected_files)

  -- Function to process a single file
  local function process_file(file_group)
    local file_path = file_group.file

    -- Skip if backup failed
    if not self.last_backup[file_path] then
      results.processed = results.processed + 1
      return
    end

    -- Read file
    local file_lines = vim.fn.readfile(file_path)
    local modified = false
    local local_matches = 0

    -- Apply replacements
    for _, match in ipairs(file_group.matches) do
      local line_idx = match.line_number
      local original_line = file_lines[line_idx] or ""
      local new_line = self:apply_replacement(original_line, search_pat, replace_pat)
      if new_line ~= original_line then
        file_lines[line_idx] = new_line
        modified = true
        local_matches = local_matches + 1
      end
    end

    -- Write file if modified
    if modified then
      local write_ok = pcall(vim.fn.writefile, file_lines, file_path)
      if write_ok then
        vim.schedule(function()
          results.files_modified = results.files_modified + 1
          results.matches_replaced = results.matches_replaced + local_matches
        end)
      else
        vim.schedule(function()
          table.insert(results.errors, "Failed to write: " .. file_path)
          self.last_backup[file_path] = nil
        end)
      end
    else
      -- No changes, remove from backup
      vim.schedule(function()
        self.last_backup[file_path] = nil
      end)
    end

    -- Update progress
    vim.schedule(function()
      results.processed = results.processed + 1
      if show_progress and progress_callback then
        progress_callback(results.processed, results.total)
      end
    end)
  end

  -- Process files with concurrency control
  local function process_next()
    if #pending_files == 0 then
      return
    end
    if active_jobs >= max_concurrent then
      return
    end

    local file_group = table.remove(pending_files, 1)
    active_jobs = active_jobs + 1

    -- Create job for async processing
    local job = Job:new({
      command = "true", -- Dummy command, we use on_start
      on_start = function()
        process_file(file_group)
      end,
      on_exit = vim.schedule_wrap(function()
        active_jobs = active_jobs - 1
        process_next() -- Process next file
      end),
    })

    table.insert(jobs, job)
    job:start()

    -- Try to start more jobs
    vim.schedule(function()
      process_next()
    end)
  end

  -- Start initial batch
  for _ = 1, math.min(max_concurrent, #selected_files) do
    process_next()
  end

  -- Wait for all jobs to complete
  local max_wait_ms = 60000 -- 60 seconds timeout
  local start_time = vim.loop.now()

  vim.wait(max_wait_ms, function()
    return results.processed >= results.total
  end, 100)

  -- Check for timeout
  if results.processed < results.total then
    table.insert(results.errors, string.format("Timeout: Only processed %d/%d files", results.processed, results.total))
  end

  return {
    files_modified = results.files_modified,
    matches_replaced = results.matches_replaced,
    errors = results.errors,
  }
end

---Restore files from last backup (undo functionality)
---@return table result { restored_count, errors }
function ReplacementEngine:restore_from_backup()
  if vim.tbl_isempty(self.last_backup) then
    return { restored_count = 0, errors = { "Nothing to undo" } }
  end

  local restored_count = 0
  local errors = {}

  for path, lines in pairs(self.last_backup) do
    if vim.fn.writefile(lines, path) == 0 then
      restored_count = restored_count + 1
    else
      table.insert(errors, "Failed to restore: " .. path)
    end
  end

  self.last_backup = {} -- Clear backup after undo

  return {
    restored_count = restored_count,
    errors = errors,
  }
end

---Check if undo is available
---@return boolean has_backup True if backup exists
function ReplacementEngine:has_backup()
  return not vim.tbl_isempty(self.last_backup)
end

return M
