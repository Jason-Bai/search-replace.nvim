-- lua/search-replace/engine/event_handlers.lua
-- Manages all keyboard bindings and event handlers

local History = require("search-replace.core.history")
local SearchOptions = require("search-replace.core.search_options")
local Browse = require("search-replace.core.browse")

local M = {}

---Setup all event handlers for the search-replace UI
---@param components table UI components (inputs, results, preview, layout)
---@param preview_mgr table PreviewManager instance
---@param replace_engine table ReplacementEngine instance
---@param callbacks table Callback functions table
function M.setup_all(components, preview_mgr, replace_engine, callbacks)
  M.setup_search_events(components, callbacks)
  M.setup_navigation_events(components, callbacks)
  M.setup_action_events(components, preview_mgr, replace_engine, callbacks)
  M.setup_close_events(components, callbacks)
end

---Helper to set input text
---@param component table NUI Input component
---@param text string Text to set
local function set_input_text(component, text)
  if component.bufnr then
    vim.api.nvim_buf_set_lines(component.bufnr, 0, -1, false, { "> " .. (text or "") })
    -- Move cursor to end
    vim.schedule(function()
      local win = component.winid
      if win and vim.api.nvim_win_is_valid(win) then
        local line = vim.api.nvim_buf_get_lines(component.bufnr, 0, 1, false)[1] or ""
        vim.api.nvim_win_set_cursor(win, { 1, #line })
      end
    end)
  end
end

---Setup search-related events (search, replace, flags inputs)
---@param components table UI components
---@param callbacks table Callback functions
function M.setup_search_events(components, callbacks)
  local inputs = components.inputs

  -- Search field: Enter key
  inputs.search:map("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
    if #lines > 0 then
      local query = lines[1]:gsub("^> %s*", "")
      History.add_search(query)
    end
    callbacks.run_search()
    callbacks.update_search_title()
  end)

  -- Search field: History navigation
  inputs.search:map("i", "<Up>", function()
    local prev = History.prev_search()
    if prev then
      set_input_text(inputs.search, prev)
    end
  end)

  inputs.search:map("i", "<Down>", function()
    local next_val = History.next_search()
    set_input_text(inputs.search, next_val or "")
  end)

  -- Replace field: Enter key
  inputs.replace:map("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(inputs.replace.bufnr, 0, 1, false)
    if #lines > 0 then
      local pattern = lines[1]:gsub("^> %s*", "")
      History.add_replace(pattern)
    end
    -- If there are results, just update preview
    if callbacks.has_results() then
      callbacks.update_preview()
    else
      callbacks.run_search()
    end
  end)

  -- Replace field: History navigation
  inputs.replace:map("i", "<Up>", function()
    local prev = History.prev_replace()
    if prev then
      set_input_text(inputs.replace, prev)
    end
  end)

  inputs.replace:map("i", "<Down>", function()
    local next_val = History.next_replace()
    set_input_text(inputs.replace, next_val or "")
  end)

  -- Flags field: Enter key
  inputs.flags:map("i", "<CR>", function()
    callbacks.run_search()
  end)

  -- Toggle search case sensitivity with <C-t> in Search field
  inputs.search:map("i", "<C-t>", function()
    SearchOptions.toggle_search_case()
    callbacks.update_search_title()

    local msg = SearchOptions.is_search_case_sensitive() and "Search: Case sensitive" or "Search: Case insensitive"
    vim.notify(msg, vim.log.levels.INFO)

    callbacks.trigger_realtime_search()
  end, { noremap = true })

  -- Toggle glob case sensitivity with <C-t> in Flags field
  inputs.flags:map("i", "<C-t>", function()
    SearchOptions.toggle_glob_case()
    callbacks.update_flags_title()

    local msg = SearchOptions.is_glob_case_sensitive() and "Glob: Case sensitive" or "Glob: Case insensitive"
    vim.notify(msg, vim.log.levels.INFO)

    callbacks.trigger_realtime_search()
  end, { noremap = true })
end

---Setup navigation events (Tab, Shift-Tab)
---@param components table UI components
---@param callbacks table Callback functions
function M.setup_navigation_events(components, callbacks)
  local inputs = components.inputs
  local results = components.results
  local preview = components.preview

  local map_opts = { nowait = true, noremap = true }

  -- Tab navigation: Search -> Replace -> Flags -> Results -> Preview -> (back to Search)
  inputs.search:map("i", "<Tab>", function()
    callbacks.focus_component(inputs.replace)
  end, map_opts)

  inputs.replace:map("i", "<Tab>", function()
    callbacks.focus_component(inputs.flags)
  end, map_opts)

  inputs.flags:map("i", "<Tab>", function()
    callbacks.focus_component(results)
  end, map_opts)

  results:map("n", "<Tab>", function()
    callbacks.focus_component(preview)
  end, map_opts)

  preview:map("n", "<Tab>", function()
    callbacks.focus_component(inputs.search)
  end, map_opts)

  -- Shift-Tab: Reverse navigation
  inputs.search:map("i", "<S-Tab>", function()
    callbacks.focus_component(preview)
  end, map_opts)

  inputs.replace:map("i", "<S-Tab>", function()
    callbacks.focus_component(inputs.search)
  end, map_opts)

  inputs.flags:map("i", "<S-Tab>", function()
    callbacks.focus_component(inputs.replace)
  end, map_opts)

  results:map("n", "<S-Tab>", function()
    callbacks.focus_component(inputs.flags)
  end, map_opts)

  preview:map("n", "<S-Tab>", function()
    callbacks.focus_component(results)
  end, map_opts)
end

---Setup action events (selection, browse, replace, undo)
---@param components table UI components
---@param preview_mgr table PreviewManager instance
---@param replace_engine table ReplacementEngine instance
---@param callbacks table Callback functions
function M.setup_action_events(components, preview_mgr, replace_engine, callbacks)
  local inputs = components.inputs
  local results = components.results
  local preview = components.preview

  -- Results navigation: update preview on cursor move
  results:on("CursorMoved", function()
    callbacks.update_preview()
  end)

  -- Toggle file selection with Space
  results:map("n", "<Space>", function()
    callbacks.toggle_file_selection()
  end)

  -- Browse mode: Open file in Preview and navigate matches with n/N
  results:map("n", "o", function()
    local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
    local grouped_files = callbacks.get_grouped_files()

    if line_idx > #grouped_files then
      vim.notify("No file selected", vim.log.levels.WARN)
      return
    end

    local file_group = grouped_files[line_idx]
    if not file_group or not file_group.file then
      vim.notify("No file selected", vim.log.levels.WARN)
      return
    end

    -- Get search pattern for highlighting
    local search_pat = ""
    if inputs.search.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
      if #lines > 0 then
        search_pat = lines[1]:gsub("^> %s*", "")
      end
    end

    -- Enter browse mode with first match of the selected file
    if file_group.matches and #file_group.matches > 0 then
      Browse.enter(
        preview,
        results,
        file_group.file,
        file_group.matches[1].line_number,
        grouped_files,
        search_pat,
        -- Pass focus switching functions for Tab navigation during Browse Mode
        {
          next = function()
            callbacks.focus_component(inputs.search)
          end,
          prev = function()
            callbacks.focus_component(results)
          end,
        }
      )
    else
      vim.notify("No matches in this file", vim.log.levels.WARN)
    end
  end)

  -- Execute replacement with 'r'
  results:map("n", "r", function()
    -- Get search and replace patterns
    local search_pat, replace_pat = preview_mgr:get_patterns()

    if search_pat == "" then
      vim.notify("Search pattern is empty!", vim.log.levels.WARN)
      return
    end

    -- Get selected files
    local selected_files = callbacks.get_selected_files()

    if #selected_files == 0 then
      vim.notify("No files selected!", vim.log.levels.WARN)
      return
    end

    -- Show initial progress notification
    vim.notify(string.format("Replacing in %d files...", #selected_files), vim.log.levels.INFO)

    -- Perform replacements with parallel execution and progress updates
    local result = replace_engine:execute_replacements_parallel(selected_files, search_pat, replace_pat, {
      max_concurrent = 20,
      show_progress = #selected_files > 10, -- Show progress for > 10 files
      progress_callback = function(processed, total)
        -- Update progress notification every 5 files
        if processed % 5 == 0 or processed == total then
          vim.notify(
            string.format("Replacing... %d/%d files", processed, total),
            vim.log.levels.INFO,
            { replace = true } -- Replace previous notification
          )
        end
      end,
    })

    -- Show result notification
    local msg = string.format(
      "Replaced %d matches in %d files. Press 'u' to undo.",
      result.matches_replaced,
      result.files_modified
    )
    if #result.errors > 0 then
      msg = msg .. "\n\nErrors:\n" .. table.concat(result.errors, "\n")
      vim.notify(msg, vim.log.levels.WARN)
    else
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Clear selection state and re-run search
    callbacks.clear_selection()
    callbacks.run_search()
  end)

  -- Implement Undo with 'u'
  results:map("n", "u", function()
    if not replace_engine:has_backup() then
      vim.notify("Nothing to undo", vim.log.levels.WARN)
      return
    end

    local result = replace_engine:restore_from_backup()

    local msg = "Undo successful: Restored " .. result.restored_count .. " files"
    if #result.errors > 0 then
      msg = msg .. "\nErrors:\n" .. table.concat(result.errors, "\n")
      vim.notify(msg, vim.log.levels.ERROR)
    else
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Refresh search results
    callbacks.run_search()
  end)
end

---Setup close events (Esc, q)
---@param components table UI components
---@param callbacks table Callback functions
function M.setup_close_events(components, callbacks)
  local inputs = components.inputs
  local results = components.results

  inputs.search:map("n", "<Esc>", callbacks.close)
  inputs.search:map("i", "<Esc>", callbacks.close)
  results:map("n", "<Esc>", callbacks.close)
  results:map("n", "q", callbacks.close)
end

return M
