-- lua/search-replace/init.lua
local Layout = require("search-replace.ui.layout")
local Inputs = require("search-replace.ui.inputs")
local Results = require("search-replace.ui.results")
local Builder = require("search-replace.core.builder")
local Parser = require("search-replace.core.parser")
local State = require("search-replace.core.state")
local Grouper = require("search-replace.core.grouper")
local Diff = require("search-replace.core.diff")
local Platform = require("search-replace.core.platform")
local History = require("search-replace.core.history")
local Config = require("search-replace.config")
local Browse = require("search-replace.core.browse")
local Popup = require("nui.popup")
local Job = require("plenary.job")

local M = {}

---Setup the plugin with user configuration
---@param opts? SearchReplaceConfig User configuration
function M.setup(opts)
  Config.setup(opts)

  local keymap = Config.get("keymap")
  if keymap and keymap ~= false then
    vim.keymap.set("n", keymap, M.open, { desc = "Search and Replace" })
  end
end

function M.open()
  -- Check if ripgrep is installed
  if vim.fn.executable("rg") ~= 1 then
    vim.notify(
      "search-replace.nvim: ripgrep (rg) not found!\n"
        .. "Please install ripgrep: https://github.com/BurntSushi/ripgrep",
      vim.log.levels.ERROR
    )
    return
  end

  State.reset() -- Reset state on open

  local inputs = Inputs.create_inputs()
  local results = Results.create_results()
  local preview = Popup({
    enter = false,
    focusable = true, -- Changed to true for Tab navigation
    border = {
      style = "rounded",
      text = {
        top = " Preview ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  local components = {
    search = inputs.search,
    replace = inputs.replace,
    flags = inputs.flags,
    results = results,
    preview = preview,
  }

  local layout = Layout.create_layout(components)
  layout:mount()

  -- Store grouped data for preview access (initialize early)
  local grouped_files = {}
  -- Track file selection state (by file path)
  local file_selection = {}

  -- Placeholder text config
  local placeholders = {
    { component = inputs.search, text = "Enter search pattern..." },
    { component = inputs.replace, text = "Leave empty for search only..." },
    { component = inputs.flags, text = "*.lua, lua/, !tests/" },
  }

  -- Placeholder namespace
  local placeholder_ns = vim.api.nvim_create_namespace("search_replace_placeholder")

  -- Function to update placeholder display
  local function update_placeholder(component, placeholder_text)
    if not component.bufnr then
      return
    end

    vim.api.nvim_buf_clear_namespace(component.bufnr, placeholder_ns, 0, -1)

    local lines = vim.api.nvim_buf_get_lines(component.bufnr, 0, 1, false)
    local content = lines[1] or ""
    -- Remove prompt "> " from content check
    content = content:gsub("^> ", "")

    if content == "" then
      vim.api.nvim_buf_set_extmark(component.bufnr, placeholder_ns, 0, 2, {
        virt_text = { { placeholder_text, "Comment" } },
        virt_text_pos = "overlay",
      })
    end
  end

  -- Setup placeholders for all inputs
  vim.schedule(function()
    for _, p in ipairs(placeholders) do
      update_placeholder(p.component, p.text)

      -- Update placeholder when buffer changes
      vim.api.nvim_buf_attach(p.component.bufnr, false, {
        on_lines = function()
          vim.schedule(function()
            update_placeholder(p.component, p.text)
          end)
          return false
        end,
      })
    end
  end)

  -- Helper to update preview - shows all matches for selected file
  local function update_preview()
    -- Don't update preview if Browse Mode is active
    if Browse.is_active() then
      return
    end

    local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]

    -- Get the file at this line
    if line_idx > #grouped_files then
      vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, {})
      return
    end

    local file_group = grouped_files[line_idx]
    if not file_group then
      vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, {})
      return
    end

    -- Get search and replace patterns
    local search_pat = ""
    if inputs.search.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
      if #lines > 0 then
        search_pat = lines[1]:gsub("^> %s*", "")
      end
    end

    local replace_pat = ""
    if inputs.replace.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.replace.bufnr, 0, 1, false)
      if #lines > 0 then
        replace_pat = lines[1]:gsub("^> %s*", "")
      end
    end

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
        local ok, new_line = pcall(string.gsub, original_line, search_pat, replace_pat)
        if not ok then
          new_line = original_line
        end

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

    vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, preview_lines)

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
      vim.bo[preview.bufnr].filetype = ft
    end

    -- Apply highlights to preview lines (diff markers)
    local highlights = Config.get("highlights")
    if highlights then
      for i, line in ipairs(preview_lines) do
        local line_idx = i - 1 -- 0-indexed
        if line:match("^%- ") then
          vim.api.nvim_buf_add_highlight(preview.bufnr, -1, highlights.preview_del, line_idx, 0, -1)
        elseif line:match("^%+ ") then
          vim.api.nvim_buf_add_highlight(preview.bufnr, -1, highlights.preview_add, line_idx, 0, -1)
        end
      end
    end

    -- Reset cursor to top of preview
    if preview.winid and vim.api.nvim_win_is_valid(preview.winid) then
      vim.api.nvim_win_set_cursor(preview.winid, { 1, 0 })
    end
  end

  -- Helper to get view items (files only)
  local function get_view_items()
    local items = State.get_results()
    -- Group by file
    grouped_files = Grouper.group_by_file(items)

    local view_items = {}
    for _, file_group in ipairs(grouped_files) do
      -- Default to selected (true) if not explicitly set
      local is_selected = file_selection[file_group.file]
      if is_selected == nil then
        is_selected = true -- Default: all files selected
      end

      table.insert(view_items, {
        file = file_group.file,
        match_count = file_group.match_count,
        selected = is_selected,
      })
    end
    return view_items
  end

  -- Search Logic
  local function run_search()
    local query = ""
    if inputs.search.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
      if #lines > 0 then
        query = lines[1]:gsub("^> %s*", "")
      end
    end

    local flags = ""
    if inputs.flags.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.flags.bufnr, 0, 1, false)
      if #lines > 0 then
        flags = lines[1]:gsub("^> %s*", "")
      end
    end

    if query == "" then
      return
    end

    local cmd_args = Builder.build_args({ search = query, flags = flags })

    -- Use cross-platform command execution
    local output, exit_code = Platform.execute(vim.fn.getcwd(), Platform.rg_executable(), cmd_args)

    if exit_code == 0 then
      local items = {}
      for _, line in ipairs(output) do
        local parsed = Parser.parse_line(line)
        if parsed then
          table.insert(items, parsed)
        end
      end

      State.set_results(items)
      Results.update_results(results, get_view_items())

      if #items > 0 then
        vim.api.nvim_win_set_cursor(results.winid, { 1, 0 })
        update_preview()
      else
        -- No matches found after replace - clear preview
        vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, { "All matches replaced!" })
      end
    else
      State.set_results({})
      grouped_files = {} -- Clear grouped files
      Results.update_results(results, {})
      vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, { "No results found" })
    end
  end

  -- Helper to set input text
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

  -- Event Wiring
  inputs.search:map("i", "<CR>", function()
    -- Save to history before searching
    local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
    if #lines > 0 then
      local query = lines[1]:gsub("^> %s*", "")
      History.add_search(query)
    end
    run_search()
  end)

  -- History navigation for Search
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

  inputs.replace:map("i", "<CR>", function()
    -- Save replace pattern to history
    local lines = vim.api.nvim_buf_get_lines(inputs.replace.bufnr, 0, 1, false)
    if #lines > 0 then
      local pattern = lines[1]:gsub("^> %s*", "")
      History.add_replace(pattern)
    end
    -- If there are results, just update preview
    if #State.get_results() > 0 then
      update_preview()
    else
      -- Otherwise trigger search
      run_search()
    end
  end)

  -- History navigation for Replace
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

  inputs.flags:map("i", "<CR>", function()
    -- Trigger search with new flags
    run_search()
  end)
  local function focus_component(component)
    if component and component.winid and vim.api.nvim_win_is_valid(component.winid) then
      vim.api.nvim_set_current_win(component.winid)
    end
  end

  -- Tab navigation: Search -> Replace -> Flags -> Results -> Preview -> (back to Search)
  local map_opts = { nowait = true, noremap = true }
  inputs.search:map("i", "<Tab>", function()
    focus_component(inputs.replace)
  end, map_opts)
  inputs.replace:map("i", "<Tab>", function()
    focus_component(inputs.flags)
  end, map_opts)
  inputs.flags:map("i", "<Tab>", function()
    focus_component(results)
  end, map_opts)
  results:map("n", "<Tab>", function()
    focus_component(preview)
  end, map_opts)
  preview:map("n", "<Tab>", function()
    focus_component(inputs.search)
  end, map_opts)

  -- Shift-Tab: Reverse navigation
  inputs.search:map("i", "<S-Tab>", function()
    focus_component(preview)
  end, map_opts)
  inputs.replace:map("i", "<S-Tab>", function()
    focus_component(inputs.search)
  end, map_opts)
  inputs.flags:map("i", "<S-Tab>", function()
    focus_component(inputs.replace)
  end, map_opts)
  results:map("n", "<S-Tab>", function()
    focus_component(inputs.flags)
  end, map_opts)
  preview:map("n", "<S-Tab>", function()
    focus_component(results)
  end, map_opts)

  -- Results navigation
  results:on("CursorMoved", function()
    update_preview()
  end)

  -- Toggle file selection with Space
  results:map("n", "<Space>", function()
    local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
    if line_idx > #grouped_files then
      return
    end -- Skip if empty/placeholder

    local file_group = grouped_files[line_idx]
    if not file_group then
      return
    end

    -- Toggle selection for this file
    local current = file_selection[file_group.file]
    if current == nil then
      current = true -- Default was selected
    end
    file_selection[file_group.file] = not current

    Results.update_results(results, get_view_items())
    -- Restore cursor
    vim.api.nvim_win_set_cursor(results.winid, { line_idx, 0 })
  end)

  -- Browse mode: Open file in Preview and navigate matches with n/N
  results:map("n", "o", function()
    local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
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
          next = function() focus_component(inputs.search) end,  -- Tab
          prev = function() focus_component(results) end,        -- Shift-Tab
        }
      )
    else
      vim.notify("No matches in this file", vim.log.levels.WARN)
    end
  end)

  -- Backup storage for undo: { ["file_path"] = { lines = { ... } } }
  local last_backup = {}

  -- Execute replacement with 'r'
  results:map("n", "r", function()
    -- Get search and replace patterns
    local search_pat = ""
    if inputs.search.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
      if #lines > 0 then
        search_pat = lines[1]:gsub("^> %s*", "")
      end
    end

    local replace_pat = ""
    if inputs.replace.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.replace.bufnr, 0, 1, false)
      if #lines > 0 then
        replace_pat = lines[1]:gsub("^> %s*", "")
      end
    end

    if search_pat == "" then
      vim.notify("Search pattern is empty!", vim.log.levels.WARN)
      return
    end

    -- Count selected files and matches
    local selected_files = {}
    local total_matches = 0
    for _, file_group in ipairs(grouped_files) do
      local is_selected = file_selection[file_group.file]
      if is_selected == nil then
        is_selected = true
      end

      if is_selected then
        table.insert(selected_files, file_group)
        total_matches = total_matches + file_group.match_count
      end
    end

    if #selected_files == 0 then
      vim.notify("No files selected!", vim.log.levels.WARN)
      return
    end

    -- Perform replacements
    local files_modified = 0
    local matches_replaced = 0
    local errors = {}

    -- Clear previous backup
    last_backup = {}

    for _, file_group in ipairs(selected_files) do
      local file_path = file_group.file
      if vim.fn.filereadable(file_path) == 1 then
        -- Check if file is writable
        if vim.fn.filewritable(file_path) ~= 1 then
          table.insert(errors, "Permission denied: " .. file_path)
        else
          local file_lines = vim.fn.readfile(file_path)

          -- Backup original content
          last_backup[file_path] = vim.deepcopy(file_lines)

          local modified = false

          for _, match in ipairs(file_group.matches) do
            local line_idx = match.line_number
            local original_line = file_lines[line_idx] or ""
            local ok, new_line = pcall(string.gsub, original_line, search_pat, replace_pat)
            if not ok then
              -- Invalid regex pattern
              table.insert(errors, "Invalid pattern: " .. tostring(new_line))
              break
            elseif new_line ~= original_line then
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
              last_backup[file_path] = nil
            end
          else
            -- No changes made, remove from backup
            last_backup[file_path] = nil
          end
        end
      else
        table.insert(errors, "File not found: " .. file_path)
      end
    end

    -- Show result notification
    local msg = string.format("Replaced %d matches in %d files. Press 'u' to undo.", matches_replaced, files_modified)
    if #errors > 0 then
      msg = msg .. "\n\nErrors:\n" .. table.concat(errors, "\n")
      vim.notify(msg, vim.log.levels.WARN)
    else
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Clear selection state and re-run search to show updated results
    file_selection = {}
    run_search()
  end)

  -- Implement Undo with 'u'
  results:map("n", "u", function()
    if vim.tbl_isempty(last_backup) then
      vim.notify("Nothing to undo", vim.log.levels.WARN)
      return
    end

    local restored_count = 0
    local errors = {}

    for path, lines in pairs(last_backup) do
      if vim.fn.writefile(lines, path) == 0 then
        restored_count = restored_count + 1
      else
        table.insert(errors, "Failed to restore: " .. path)
      end
    end

    last_backup = {} -- Clear backup after undo

    local msg = "Undo successful: Restored " .. restored_count .. " files"
    if #errors > 0 then
      msg = msg .. "\nErrors:\n" .. table.concat(errors, "\n")
      vim.notify(msg, vim.log.levels.ERROR)
    else
      vim.notify(msg, vim.log.levels.INFO)
    end

    -- Refresh search results
    run_search()
  end)

  local function close()
    layout:unmount()
  end

  inputs.search:map("n", "<Esc>", close)
  inputs.search:map("i", "<Esc>", close)
  results:map("n", "<Esc>", close)
  results:map("n", "q", close)

  -- Initial focus
  vim.schedule(function()
    focus_component(inputs.search)
  end)
end

return M
