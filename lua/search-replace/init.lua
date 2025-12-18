-- lua/search-replace/init.lua
-- Main plugin entry point - orchestrates UI components and engines

local Layout = require("search-replace.ui.layout")
local Inputs = require("search-replace.ui.inputs")
local Results = require("search-replace.ui.results")
local Builder = require("search-replace.core.builder")
local Parser = require("search-replace.core.parser")
local State = require("search-replace.core.state")
local Grouper = require("search-replace.core.grouper")
local Platform = require("search-replace.core.platform")
local Config = require("search-replace.config")
local Browse = require("search-replace.core.browse")
local SearchOptions = require("search-replace.core.search_options")
local PreviewManager = require("search-replace.engine.preview_manager")
local ReplacementEngine = require("search-replace.engine.replacement_engine")
local EventHandlers = require("search-replace.engine.event_handlers")
local Popup = require("nui.popup")

local M = {}

---Get visual selection text
---@return string|nil selected_text The selected text, or nil if multi-line or error
function M.get_visual_selection()
  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  -- Only support single-line selection for now
  if start_line ~= end_line then
    vim.notify("Multi-line selection not supported for search", vim.log.levels.WARN)
    return nil
  end

  -- Get the selected text
  local line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
  if not line then
    return nil
  end

  local selected = line:sub(start_col, end_col)

  -- Escape for ripgrep if configured
  local visual_config = Config.get("visual") or {}
  if visual_config.escape_regex ~= false then
    return M.escape_for_rg(selected)
  end

  return selected
end

---Escape special characters for ripgrep regex
---@param text string Text to escape
---@return string escaped_text
function M.escape_for_rg(text)
  -- Escape ripgrep regex special characters: . * + ? ^ $ { } [ ] ( ) | \
  return text:gsub("([%.%*%+%?%^%$%{%}%[%]%(%)%|\\])", "\\%1")
end

---Setup the plugin with user configuration
---@param opts? SearchReplaceConfig User configuration
function M.setup(opts)
  Config.setup(opts)

  local keymap = Config.get("keymap")
  if keymap and keymap ~= false then
    -- Normal mode keymap
    vim.keymap.set("n", keymap, M.open, { desc = "Search and Replace" })

    -- Visual mode keymap
    vim.keymap.set("v", keymap, M.open_visual, { desc = "Search and Replace (visual)" })
  end
end

---Open search-replace from visual mode with selection pre-filled
---This function handles exiting visual mode and extracting the selection
---Use this when setting up lazy.nvim keys for visual mode
function M.open_visual()
  -- Save the visual selection before exiting visual mode
  -- We need to yank the selection first while still in visual mode
  local saved_reg = vim.fn.getreg("v")
  local saved_regtype = vim.fn.getregtype("v")

  -- Yank visual selection to register "v"
  vim.cmd('normal! "vy')
  local visual_text = vim.fn.getreg("v")

  -- Restore the register
  vim.fn.setreg("v", saved_reg, saved_regtype)

  -- Escape regex special characters if configured
  local visual_config = Config.get("visual") or {}
  if visual_config.escape_regex ~= false and visual_text then
    visual_text = M.escape_for_rg(visual_text)
  end

  -- Open with the visual text
  M.open({ visual = true, visual_text = visual_text })
end

---Main open function - creates UI and wires everything together
---@param opts? table Options { visual, visual_text }
function M.open(opts)
  opts = opts or {}

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

  -- Get visual text - either passed from open_visual() or extracted here
  local visual_text = nil
  if opts.visual then
    -- Prefer visual_text from opts (set by open_visual)
    if opts.visual_text then
      visual_text = opts.visual_text
    else
      -- Fallback: try to get from selection marks (legacy support)
      visual_text = M.get_visual_selection()
    end
  end

  -- ========================================
  -- 1. Create UI Components
  -- ========================================
  local inputs = Inputs.create_inputs()
  local results = Results.create_results()
  local preview = Popup({
    enter = false,
    focusable = true,
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
    inputs = inputs,
    search = inputs.search,
    replace = inputs.replace,
    flags = inputs.flags,
    results = results,
    preview = preview,
  }

  local layout = Layout.create_layout(components)
  layout:mount()

  -- ========================================
  -- 2. Initialize Engines
  -- ========================================
  local preview_mgr = PreviewManager.new(preview, inputs)
  local replace_engine = ReplacementEngine.new()

  -- ========================================
  -- 3. State Management
  -- ========================================
  local grouped_files = {}
  local file_selection = {}

  -- Helper to get view items (files only)
  local function get_view_items()
    local items = State.get_results()
    grouped_files = Grouper.group_by_file(items)

    local view_items = {}
    for _, file_group in ipairs(grouped_files) do
      local is_selected = file_selection[file_group.file]
      if is_selected == nil then
        is_selected = true
      end

      table.insert(view_items, {
        file = file_group.file,
        match_count = file_group.match_count,
        selected = is_selected,
      })
    end
    return view_items
  end

  -- ========================================
  -- 4. Search Logic
  -- ========================================
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
        preview_mgr:set_grouped_files(grouped_files)
        preview_mgr:update_preview(results, Browse.is_active)
      else
        vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, { "All matches replaced!" })
      end
    else
      State.set_results({})
      grouped_files = {}
      Results.update_results(results, {})
      vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, { "No results found" })
    end
  end

  -- ========================================
  -- 5. Realtime Search Setup
  -- ========================================
  local realtime_config = Config.get("realtime") or {}
  local search_timer = nil
  local last_match_count = 0

  local function update_search_title_with_count(count_or_status)
    local case_status = SearchOptions.get_search_status_text()
    local count_text = ""

    if count_or_status == "..." then
      count_text = "[...]"
    elseif type(count_or_status) == "number" and count_or_status > 0 then
      count_text = string.format("[%d]", count_or_status)
    end

    local title = string.format(" Search %s %s ", case_status, count_text)
    if inputs.search.border then
      inputs.search.border:set_text("top", title, "center")
    end
  end

  local function trigger_realtime_search()
    if search_timer then
      vim.fn.timer_stop(search_timer)
      search_timer = nil
    end

    local search_text = ""
    if inputs.search.bufnr then
      local lines = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, 1, false)
      if #lines > 0 then
        search_text = lines[1]:gsub("^> %s*", "")
      end
    end

    local min_chars = realtime_config.min_chars or 2
    if #search_text < min_chars then
      State.set_results({})
      grouped_files = {}
      Results.update_results(results, {})
      vim.api.nvim_buf_set_lines(preview.bufnr, 0, -1, false, {})
      update_search_title_with_count(0)
      last_match_count = 0
      return
    end

    update_search_title_with_count("...")

    local debounce_ms = realtime_config.debounce_ms or 300
    search_timer = vim.fn.timer_start(debounce_ms, function()
      vim.schedule(function()
        run_search()
        last_match_count = #State.get_results()
        update_search_title_with_count(last_match_count)
      end)
    end)
  end

  local function trigger_realtime_preview()
    if last_match_count > 0 then
      vim.schedule(function()
        preview_mgr:set_grouped_files(grouped_files)
        preview_mgr:update_preview(results, Browse.is_active)
      end)
    end
  end

  if realtime_config.enabled ~= false then
    vim.api.nvim_buf_attach(inputs.search.bufnr, false, {
      on_lines = function()
        vim.schedule(function()
          preview_mgr:clear_cache() -- Clear cache when search pattern changes
          trigger_realtime_search()
        end)
        return false
      end,
    })

    vim.api.nvim_buf_attach(inputs.flags.bufnr, false, {
      on_lines = function()
        vim.schedule(function()
          preview_mgr:clear_cache() -- Clear cache when flags change
          trigger_realtime_search()
        end)
        return false
      end,
    })

    vim.api.nvim_buf_attach(inputs.replace.bufnr, false, {
      on_lines = function()
        vim.schedule(function()
          preview_mgr:clear_cache() -- Clear cache when replace pattern changes
          trigger_realtime_preview()
        end)
        return false
      end,
    })
  end

  -- ========================================
  -- 6. Placeholder Setup
  -- ========================================
  local placeholders = {
    { component = inputs.search, text = "Enter search pattern..." },
    { component = inputs.replace, text = "Leave empty for search only..." },
    { component = inputs.flags, text = "e.g. *.lua, src/, !tests/" },
  }

  local placeholder_ns = vim.api.nvim_create_namespace("search_replace_placeholder")

  local function update_placeholder(component, placeholder_text)
    if not component.bufnr then
      return
    end

    vim.api.nvim_buf_clear_namespace(component.bufnr, placeholder_ns, 0, -1)

    local lines = vim.api.nvim_buf_get_lines(component.bufnr, 0, 1, false)
    local content = lines[1] or ""
    content = content:gsub("^> ", "")

    if content == "" then
      vim.api.nvim_buf_set_extmark(component.bufnr, placeholder_ns, 0, 2, {
        virt_text = { { placeholder_text, "Comment" } },
        virt_text_pos = "overlay",
      })
    end
  end

  vim.schedule(function()
    for _, p in ipairs(placeholders) do
      update_placeholder(p.component, p.text)

      vim.api.nvim_buf_attach(p.component.bufnr, false, {
        on_lines = function()
          vim.schedule(function()
            update_placeholder(p.component, p.text)
          end)
          return false
        end,
      })
    end

    -- Pre-fill visual selection
    if visual_text and #visual_text > 0 then
      local visual_config = Config.get("visual") or {}

      vim.api.nvim_buf_set_lines(inputs.search.bufnr, 0, -1, false, { "> " .. visual_text })

      if inputs.search.winid and vim.api.nvim_win_is_valid(inputs.search.winid) then
        local line_len = #visual_text + 2
        vim.api.nvim_win_set_cursor(inputs.search.winid, { 1, line_len })
      end

      if visual_config.auto_focus_replace ~= false then
        vim.schedule(function()
          focus_component(inputs.replace)
        end)
      end
    end
  end)

  -- ========================================
  -- 7. Title Updates
  -- ========================================
  local function update_flags_title()
    local status_text = SearchOptions.get_glob_status_text()
    local title = string.format(" Flags %s ", status_text)

    if inputs.flags.border then
      inputs.flags.border:set_text("top", title, "center")
    end
  end

  vim.schedule(function()
    update_search_title_with_count(0)
    update_flags_title()
  end)

  -- ========================================
  -- 8. Helper Functions for Callbacks
  -- ========================================
  local function focus_component(component)
    if component and component.winid and vim.api.nvim_win_is_valid(component.winid) then
      vim.api.nvim_set_current_win(component.winid)
    end
  end

  local function close()
    layout:unmount()
  end

  -- ========================================
  -- 9. Setup Event Handlers
  -- ========================================
  local callbacks = {
    run_search = run_search,
    update_preview = function()
      preview_mgr:set_grouped_files(grouped_files)
      preview_mgr:update_preview(results, Browse.is_active)
    end,
    has_results = function()
      return #State.get_results() > 0
    end,
    update_search_title = function()
      update_search_title_with_count(last_match_count)
    end,
    update_flags_title = update_flags_title,
    trigger_realtime_search = trigger_realtime_search,
    focus_component = focus_component,
    close = close,
    get_grouped_files = function()
      return grouped_files
    end,
    toggle_file_selection = function()
      local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
      if line_idx > #grouped_files then
        return
      end

      local file_group = grouped_files[line_idx]
      if not file_group then
        return
      end

      local current = file_selection[file_group.file]
      if current == nil then
        current = true
      end
      file_selection[file_group.file] = not current

      Results.update_results(results, get_view_items())
      vim.api.nvim_win_set_cursor(results.winid, { line_idx, 0 })
    end,
    get_selected_files = function()
      local selected_files = {}
      for _, file_group in ipairs(grouped_files) do
        local is_selected = file_selection[file_group.file]
        if is_selected == nil then
          is_selected = true
        end

        if is_selected then
          table.insert(selected_files, file_group)
        end
      end
      return selected_files
    end,
    clear_selection = function()
      file_selection = {}
    end,
  }

  EventHandlers.setup_all(components, preview_mgr, replace_engine, callbacks)

  -- ========================================
  -- 10. Initial Focus
  -- ========================================
  vim.schedule(function()
    focus_component(inputs.search)
  end)
end

return M
