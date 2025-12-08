# Browse Mode Design Document

## Overview

This document describes the design for the **Browse Mode** feature - an enhancement that allows users to navigate through search matches using keyboard shortcuts, similar to Vim's quickfix list.

**Status**: Planned for v0.2.0+
**Created**: 2024-12-05
**Author**: Design discussion with user

---

## Motivation

### Current Workflow (v0.1.x)

- User searches for a pattern
- Results window shows all matches grouped by file
- Preview window shows context or diff for selected item
- Primary use case: **Batch replacement**

### Gap

Users may want to **browse through matches** before deciding to replace:

- Inspect each occurrence in context
- Navigate quickly between matches
- Review matches across multiple files

---

## Design Principle

**Key Insight**: Extend Preview window to support file browsing while keeping the core batch-replacement workflow intact.

### Current Architecture

```
┌─────────────┬──────────────┐
│   Results   │   Preview    │
│             │              │
│ ✓ file1.lua │ (context or  │
│   file2.lua │  diff view)  │
│   file3.lua │              │
└─────────────┴──────────────┘
```

### With Browse Mode

```
Results                         Preview (Browse Mode)
─────────────────────────────  ───────────────────────────
✓ src/main.lua (3 matches)     📄 src/main.lua:42
  src/util.lua (2 matches)     ───────────────────────────
  test/foo.lua (1 match)       38: function init()
                                39:   local config = {}
                                40:   -- some code
[Space: toggle | o: browse]    41:
[r: replace | u: undo]          42:   local search = "TODO" ← 🔍 CURRENT
                                43:   return result
                                44: end
                                45:
                                46: function process()

                                [n: next | N: prev | q: exit]
```

**Design Rationale**:
- **Results window** shows file-level information only
  - No line numbers displayed (they add visual noise)
  - User operates at file granularity (Space toggles entire file)
  - Want details? Press `o` to enter Browse Mode
- **Browse Mode** is the detail view
  - Shows exact line numbers and context
  - Navigate with `n/N` to inspect each match
  - Clear separation of concerns: Results = file manager, Preview = content browser

---

## User Experience Flow

### Scenario 1: Browse Before Replace

```
1. User searches "TODO"
2. Results shows 20 files with match counts:
   ✓ src/main.lua (8 matches)
   ✓ src/util.lua (15 matches)
   ✓ tests/test.lua (3 matches)
   ...
3. Press `o` → Enter Browse Mode, see first match in first file
4. Press `n n n` → Browse through all TODO comments across files
5. Press `q` → Return to Results window
6. Use `Space` to select/deselect files for replacement
7. Press `r` → Execute batch replace on selected files
```

### Scenario 2: Quick Review

```
1. User searches "old_api"
2. Results shows:
   src/api.lua (5 matches)
   src/handlers.lua (3 matches)
   lib/compat.lua (2 matches)
3. Press `o` → Enter Browse Mode
4. Use `n/N` to review several occurrences in detail
5. Decide: "Only need to replace in src/ folder"
6. Press `q` → Return to Results
7. Deselect lib/compat.lua with Space
8. Press `r` → Replace only in selected files
```

---

## Keyboard Mappings

### Results Window

| Key     | Action                                 |
| ------- | -------------------------------------- |
| `o`     | Open file in Preview at match position |
| `Space` | Toggle file selection (unchanged)      |
| `r`     | Execute replacement (unchanged)        |
| `u`     | Undo last replacement (unchanged)      |

### Preview Window (Browse Mode)

| Key   | Action                                          |
| ----- | ----------------------------------------------- |
| `n`   | Jump to next match (in current file, then next) |
| `N`   | Jump to previous match                          |
| `q`   | Exit browse mode, return to preview mode        |
| `Tab` | Focus back to Results (unchanged)               |

**Future enhancements** (v0.3.0):

- `gg` - Jump to first match (global)
- `G` - Jump to last match (global)
- `{count}n` - Jump forward N matches
- `/` - Search within current file

---

## Implementation Plan

### Phase 1: v0.2.0 - Basic Browse Mode

#### 1.1 Results Window - Add `o` Key

**File**: `lua/search-replace/init.lua`

**Results Display Format** (file-level only, no line numbers):
```lua
-- Results window content structure
local results_lines = {
  "src/main.lua (8 matches)",    -- File entry (selectable)
  "src/util.lua (15 matches)",   -- No child line items
  "tests/test.lua (3 matches)",  -- Simple flat list
}

-- Each line maps to a file with all its matches
local file_data = {
  { file = "src/main.lua", matches = { {line=42, col=10, ...}, {line=58, ...}, ... } },
  { file = "src/util.lua", matches = { ... } },
  ...
}
```

**Keymap Implementation**:
```lua
results:map("n", "o", function()
  local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
  local file_entry = file_data[line_idx]

  if not file_entry then
    vim.notify("Select a file to browse", vim.log.levels.WARN)
    return
  end

  -- Enter browse mode with first match of the selected file
  browse.enter(
    preview_win,
    results_win,
    file_entry.file,
    file_entry.matches[1].line,  -- Start at first match
    file_data  -- Pass all files for cross-file navigation (v0.3.0)
  )
end)
```

**Why this design**:
- Results operates at **file granularity** (user selects files, not lines)
- No visual clutter from line numbers that aren't individually actionable
- Press `o` on any file → Browse Mode shows all matches in that file
- Browse Mode handles line-level navigation with `n/N`

#### 1.2 Preview Window - Browse Mode State

**File**: `lua/search-replace/core/browse.lua` (new)

```lua
local M = {}

-- Namespace for highlight management
local ns_id = vim.api.nvim_create_namespace('search_replace_browse')

-- State (designed for future cross-file navigation in v0.3.0)
local browse_state = {
  active = false,
  current_file_idx = 1,    -- Current file in global list (for v0.3.0)
  current_match_idx = 1,   -- Current match in current file
  files_list = {},         -- { {file="path", matches={...}}, ... }

  -- Window references
  preview_win = nil,
  results_win = nil,

  -- Buffer references
  preview_buf = nil,
}

function M.enter(preview_window, results_window, file_path, line_number, all_files_data)
  browse_state.active = true
  browse_state.preview_win = preview_window
  browse_state.results_win = results_window
  browse_state.files_list = all_files_data

  -- Load file content into preview buffer
  local file_lines = vim.fn.readfile(file_path)
  vim.api.nvim_buf_set_lines(preview_window.bufnr, 0, -1, false, file_lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(preview_window.bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(preview_window.bufnr, 'buftype', 'nofile')

  -- Store all matches for this file
  browse_state.current_file_idx = find_file_index(file_path)
  browse_state.current_match_idx = find_match_index(line_number)

  -- Highlight current match using namespace
  highlight_current_match()

  -- **CRITICAL: Transfer focus to Preview window**
  vim.api.nvim_set_current_win(preview_window.winid)

  -- Set cursor position
  vim.api.nvim_win_set_cursor(preview_window.winid, { line_number, 0 })

  -- Enable n/N navigation (buffer-local mappings)
  vim.keymap.set('n', 'n', M.next_match, { buffer = preview_window.bufnr, noremap = true })
  vim.keymap.set('n', 'N', M.prev_match, { buffer = preview_window.bufnr, noremap = true })
  vim.keymap.set('n', 'q', M.exit, { buffer = preview_window.bufnr, noremap = true })

  -- Update title bar
  update_title_bar()
end

function M.next_match()
  -- Move to next match in current file
  -- (v0.3.0: If at end, jump to next file's first match)
  local current_file = browse_state.files_list[browse_state.current_file_idx]

  if browse_state.current_match_idx < #current_file.matches then
    browse_state.current_match_idx = browse_state.current_match_idx + 1
    jump_to_match()
  else
    -- For v0.2.0: wrap around or show message
    vim.notify("Last match in file", vim.log.levels.INFO)
    -- For v0.3.0: jump to next file
  end
end

function M.prev_match()
  -- Move to previous match
  if browse_state.current_match_idx > 1 then
    browse_state.current_match_idx = browse_state.current_match_idx - 1
    jump_to_match()
  else
    vim.notify("First match in file", vim.log.levels.INFO)
  end
end

function M.exit()
  -- Clear highlights using namespace (clean and efficient)
  vim.api.nvim_buf_clear_namespace(browse_state.preview_buf, ns_id, 0, -1)

  -- Remove buffer-local keymaps
  vim.keymap.del('n', 'n', { buffer = browse_state.preview_buf })
  vim.keymap.del('n', 'N', { buffer = browse_state.preview_buf })
  vim.keymap.del('n', 'q', { buffer = browse_state.preview_buf })

  -- **CRITICAL: Return focus to Results window**
  vim.api.nvim_set_current_win(browse_state.results_win.winid)

  -- Reset state
  browse_state.active = false
  browse_state.files_list = {}

  -- Return to normal preview mode
end

-- Helper: Highlight current match using namespace
local function highlight_current_match()
  local match = get_current_match()
  if not match then return end

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(browse_state.preview_buf, ns_id, 0, -1)

  -- Highlight the search pattern (use IncSearch for visibility)
  vim.api.nvim_buf_add_highlight(
    browse_state.preview_buf,
    ns_id,
    'IncSearch',
    match.line - 1,  -- 0-indexed
    match.col_start,
    match.col_end
  )

  -- Optionally highlight the entire line with CursorLine
  vim.api.nvim_buf_add_highlight(
    browse_state.preview_buf,
    ns_id,
    'CursorLine',
    match.line - 1,
    0,
    -1
  )
end

-- Helper: Jump to current match
local function jump_to_match()
  local match = get_current_match()
  vim.api.nvim_win_set_cursor(browse_state.preview_win.winid, { match.line, match.col_start })
  highlight_current_match()
  update_title_bar()
end

return M
```

#### 1.3 Preview Buffer Content

**Display**:

```
38: function init()
39:   local config = {}
40:   -- some code
41:
42:   local search = "TODO"  ← 🔍 Highlighted line
43:   return result
44: end
```

**Highlights**:

- Current line: `CursorLine` or custom `SearchReplaceBrowseLine`
- Search keyword: `IncSearch` or `Search`
- Line numbers: `LineNr`

**Highlight Strategy** (Critical for implementation):

1. **Use Namespace API** (Modern approach):

   ```lua
   -- Create namespace once at module load
   local ns_id = vim.api.nvim_create_namespace('search_replace_browse')

   -- Add highlights
   vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'IncSearch', line-1, col_start, col_end)

   -- Clear all highlights when exiting or moving to next match
   vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
   ```

2. **Why NOT use `vim.fn.matchadd()`**:

   - ❌ Harder to manage lifecycle (need to track match IDs)
   - ❌ Can conflict with user's own search highlights (`/` search)
   - ❌ No automatic cleanup on buffer wipe
   - ✅ Namespace API is cleaner and more modern

3. **Highlight Layers**:
   - **Layer 1**: CursorLine (entire line background) - subtle
   - **Layer 2**: IncSearch (search pattern) - prominent
   - Both use the same namespace for unified cleanup

#### 1.4 UI Indicators

**Preview title bar** (dynamic):

```lua
-- Normal preview mode
border.text.top = " Preview "

-- Browse mode
border.text.top = string.format(
  " Browse [%d/%d] - %s:%d (n:next N:prev q:exit) ",
  current_match_idx,  -- Current match in file
  total_matches,      -- Total matches in current file
  vim.fn.fnamemodify(file_path, ":~:."),
  current_line
)

-- Example: " Browse [3/8] - src/main.lua:58 (n:next N:prev q:exit) "
```

**Results title bar** (updated to include 'o' key):

```lua
-- Simple, file-focused hints
top = " Results (Space: toggle | o: browse | r: replace | u: undo) "
```

**Results window content** (simplified format):

```lua
-- No tree structure, just flat file list with match counts
local function format_results(files)
  local lines = {}
  for _, file in ipairs(files) do
    local selected_marker = file.selected and "✓" or " "
    local match_count = #file.matches
    local match_text = match_count == 1 and "match" or "matches"
    table.insert(lines, string.format("%s %s (%d %s)",
      selected_marker,
      vim.fn.fnamemodify(file.path, ":~:."),
      match_count,
      match_text
    ))
  end
  return lines
end

-- Example output:
-- ✓ src/main.lua (8 matches)
-- ✓ src/util.lua (15 matches)
--   tests/test.lua (3 matches)
```

---

### Phase 2: v0.3.0 - Enhanced Navigation

#### 2.1 Cross-File Navigation

- `n` at last match in file → jump to next file's first match
- `N` at first match in file → jump to prev file's last match
- Global progress indicator: `Match 15/87 | File 3/12`

#### 2.2 Jump Commands

```lua
-- Jump to first/last globally
preview:map("n", "gg", jump_to_first_match_global)
preview:map("n", "G", jump_to_last_match_global)

-- Count prefix support
preview:map("n", "n", function()
  local count = vim.v.count1
  jump_forward_matches(count)
end)
```

#### 2.3 Progress Display

**Status line at bottom of Preview**:

```
Match 5/23 in file.lua | Total 87 matches in 12 files | [n]ext [N]prev [q]uit
```

---

## Technical Details

### Data Structure

#### Match List (per file)

```lua
local matches_in_file = {
  { line = 42, col = 10, text = "local search = 'TODO'" },
  { line = 58, col = 5,  text = "-- TODO: refactor" },
  { line 104, col = 15, text = "result.todo = true" },
}
```

#### Global Match Index

```lua
local global_matches = {
  { file = "src/main.lua", matches = { ... } },
  { file = "src/util.lua", matches = { ... } },
  ...
}
```

### Window Management

**Focus Flow** (Critical for UX):

```
┌─────────────────────────────────────────────────────┐
│ User Journey: Focus Transitions                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│ 1. [Results Window] ← User starts here             │
│    ↓ Press 'o'                                      │
│                                                     │
│ 2. [Preview Window] ← Focus transferred            │
│    • Can use n/N to navigate matches               │
│    • Can use j/k to scroll for context             │
│    • Can press Tab to go back to Results           │
│    ↓ Press 'q'                                      │
│                                                     │
│ 3. [Results Window] ← Focus returned               │
│    • Can select files with Space                   │
│    • Can press 'r' to replace                      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Implementation Details**:

1. **Entering Browse Mode** (`o` key in Results):

   ```lua
   -- File: lua/search-replace/init.lua
   results:map("n", "o", function()
     local item = get_selected_match()

     -- Transfer focus to Preview window
     browse.enter(preview_win, results_win, item.file, item.line)
     -- At this point, cursor is in Preview window
   end)
   ```

2. **Inside Browse Mode** (focus in Preview):

   ```lua
   -- All keymaps are buffer-local to Preview buffer
   vim.keymap.set('n', 'n', next_match, { buffer = preview_buf })
   vim.keymap.set('n', 'N', prev_match, { buffer = preview_buf })
   vim.keymap.set('n', 'q', exit_browse, { buffer = preview_buf })

   -- User can still use:
   -- - j/k to scroll
   -- - gg/G to jump to top/bottom
   -- - Tab to return to Results (existing mapping)
   ```

3. **Exiting Browse Mode** (`q` key or Tab):

   ```lua
   function M.exit()
     -- Clean up highlights
     vim.api.nvim_buf_clear_namespace(preview_buf, ns_id, 0, -1)

     -- Clean up keymaps
     vim.keymap.del('n', 'n', { buffer = preview_buf })
     vim.keymap.del('n', 'N', { buffer = preview_buf })
     vim.keymap.del('n', 'q', { buffer = preview_buf })

     -- Return focus to Results window
     vim.api.nvim_set_current_win(results_win.winid)
   end
   ```

**Why Focus Transfer is Critical**:

- ❌ Without focus transfer: User presses `n` but nothing happens (keymap not active)
- ✅ With focus transfer: User can immediately navigate with `n/N`
- ✅ User can use `j/k` to see more context around matches
- ✅ Natural Vim workflow: "I'm now working in this window"

**Preview Buffer**:

- Use `vim.api.nvim_buf_set_lines()` to load file content
- Use `vim.api.nvim_buf_add_highlight()` for match highlighting
- Set buffer options: `modifiable = false`, `buftype = 'nofile'`

**Cursor Management**:

```lua
-- Set cursor to match position
vim.api.nvim_win_set_cursor(preview.winid, { line_number, col_start })

-- Use namespace API for highlights (NOT matchadd)
local ns_id = vim.api.nvim_create_namespace('search_replace_browse')
vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'IncSearch', line-1, col_start, col_end)
```

---

## Edge Cases

### 1. File Content Changed

- **Problem**: File was modified after search
- **Solution**: Show warning if line content doesn't match expected pattern
  ```
  ⚠️  File modified since search - line 42 content mismatch
  ```

### 2. Large Files

- **Problem**: Loading 10,000+ line files
- **Solution (v0.2.0)**: Load entire file (simple and fast for most cases)
  ```lua
  -- Most source files are < 1MB, loading is instant
  local file_lines = vim.fn.readfile(file_path)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, file_lines)
  ```
- **Future optimization (v0.3.0+)**: Partial loading for huge files
  ```lua
  -- Only if file size > 1MB or > 10k lines
  if vim.fn.getfsize(file_path) > 1024 * 1024 then
    local start_line = math.max(1, match_line - 50)
    local end_line = math.min(total_lines, match_line + 50)
    -- Load partial content with dynamic expansion on scroll
  end
  ```
- **Rationale**: Avoid premature optimization; most code files load instantly

### 3. No More Matches

- **Problem**: User presses `n` at last match
- **Solution**:
  - Option A: Wrap around to first match (with notification)
  - Option B: Show message "Last match reached"
  - **Recommended**: Option A (consistent with Vim's `/` search)

### 4. Binary Files

- **Problem**: User tries to browse a binary file match
- **Solution**: Show message "Cannot preview binary file"

---

## Configuration

### User Config (future)

```lua
require("search-replace").setup({
  browse = {
    enabled = true,  -- Enable browse mode
    context_lines = 10,  -- Lines of context around match
    wrap_navigation = true,  -- Wrap n/N at boundaries
    cross_file_jump = true,  -- Allow n/N to jump between files
  },
})
```

---

## Testing Plan

### Unit Tests

- `tests/spec/browse_spec.lua`
  - `should enter browse mode when pressing 'o'`
  - `should jump to next match with 'n'`
  - `should jump to previous match with 'N'`
  - `should exit browse mode with 'q'`

### Integration Tests

- Navigate through multiple files
- Handle edge cases (last match, first match, wrap around)
- Verify highlights are applied correctly

---

## Documentation Updates

### README.md

Add Browse Mode section:

```markdown
### Browse Mode

Quickly navigate through search matches before replacing:

1. Search for a pattern
2. Press `o` in Results to open file at match
3. Use `n`/`N` to jump between matches
4. Press `q` to exit browse mode
5. Select files and press `r` to replace
```

### Vim Help

```vimdoc
BROWSE MODE                                    *search-replace-browse-mode*

Press 'o' in the Results window to enter Browse Mode. In this mode, you can
navigate through search matches using Vim-like keybindings.

Keybindings:
  n         Jump to next match
  N         Jump to previous match
  q         Exit browse mode
  Tab       Return to Results window
```

---

## Similar Tools Comparison

| Tool             | Navigation    | Cross-file | Preview |
| ---------------- | ------------- | ---------- | ------- |
| **Telescope**    | `<C-n>/<C-p>` | Yes        | Live    |
| **vim quickfix** | `:cn/:cp`     | Yes        | No      |
| **FZF**          | Arrow keys    | Yes        | Static  |
| **Our plugin**   | `n/N`         | Yes (v0.3) | Live    |

---

## Future Enhancements (v0.4.0+)

### 1. Split View Option

```
┌────────┬─────────┬──────────┐
│Results │ Preview │ Editor   │ ← Open actual file here
├────────┤ (Browse)│          │
│        │         │          │
└────────┴─────────┴──────────┘
```

### 2. Inline Edit in Browse Mode

- Press `e` to edit current line directly in Preview
- Save changes without closing dialog

### 3. Batch Operations

- Mark matches with `m` in browse mode
- Replace only marked matches (not whole file)

---

## References

- Vim quickfix: `:help quickfix`
- Telescope.nvim: [Mappings documentation](https://github.com/nvim-telescope/telescope.nvim#default-mappings)
- NUI.nvim: [Menu component](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/menu)

---

## Changelog

- **2024-12-05**: Initial design document created
- **2024-12-08**: Added critical implementation details:
  - **Results window simplification**: File-level display only (no line numbers)
  - Window focus management strategy
  - Highlight management using namespace API
  - Forward-compatible data structure design
  - Testing checklist for v0.2.0
  - Design rationale: Results as file manager, Browse Mode as detail inspector
- **TBD**: Implementation started (v0.2.0)
- **TBD**: Enhanced navigation (v0.3.0)

---

## Notes

- Keep the core batch-replacement workflow simple and fast
- Browse mode is an **optional enhancement**, not a replacement
- Maintain consistency with Vim's `n/N` navigation pattern
- Prioritize performance: lazy-load file content, virtualize long files

---

## Implementation Notes (Added 2024-12-08)

### Critical Technical Decisions

#### 1. **Results Window Simplification** ⭐ DESIGN DECISION
- **Decision**: Display only file names with match counts, no line numbers
- **Format**: `✓ src/main.lua (8 matches)` instead of tree structure with line numbers
- **Why**:
  - ✅ **Correct granularity**: Results operates at file level (Space toggles files, not lines)
  - ✅ **No false affordance**: Showing line numbers suggests they're individually actionable, but they're not
  - ✅ **Reduced visual noise**: 20 files with 10 matches each = 20 lines instead of 220
  - ✅ **Clear separation**: Results = file manager, Browse Mode = line-level inspector
  - ✅ **Consistent with design**: Browse Mode is the "detail view" for inspecting matches
- **User workflow**: Want to see line details? Press `o` to enter Browse Mode

#### 2. **Window Focus Management** ⭐ CRITICAL

- **Decision**: Transfer focus to Preview window when entering browse mode
- **Implementation**:
  - Enter: `vim.api.nvim_set_current_win(preview_win.winid)`
  - Exit: `vim.api.nvim_set_current_win(results_win.winid)`
- **Why**: Without focus transfer, keymaps (`n/N/q`) won't work; user expects to "be in" the Preview window
- **User benefit**: Natural Vim workflow, can use `j/k` to scroll context

#### 3. **Highlight Management** ⭐ CRITICAL

- **Decision**: Use `vim.api.nvim_buf_add_highlight()` with namespace, NOT `vim.fn.matchadd()`
- **Implementation**:
  ```lua
  local ns_id = vim.api.nvim_create_namespace('search_replace_browse')
  vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'IncSearch', line-1, col_start, col_end)
  -- Cleanup: vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  ```
- **Why**:
  - ✅ Cleaner lifecycle management
  - ✅ No conflict with user's `/` search highlights
  - ✅ Modern Neovim API
- **Avoid**: `matchadd()` requires tracking match IDs and manual cleanup

#### 4. **Data Structure Forward Compatibility**

- **Decision**: Design `browse_state` for v0.3.0 cross-file navigation now
- **Implementation**:
  ```lua
  browse_state = {
    current_file_idx = 1,    -- For future cross-file navigation
    current_match_idx = 1,
    files_list = {{file="...", matches={...}}, ...}
  }
  ```
- **Why**: Avoid data structure refactoring when adding cross-file navigation
- **v0.2.0**: Only use `files_list[1]`
- **v0.3.0**: Increment `current_file_idx` when pressing `n` at last match

#### 5. **Large File Strategy**

- **Decision**: v0.2.0 loads entire file; optimize later if needed
- **Why**: Premature optimization is evil; most source files < 1MB load instantly
- **Future**: Add threshold check only when users report performance issues

#### 6. **Keymap Scope**

- **Decision**: Use buffer-local keymaps for `n/N/q` in Preview
- **Implementation**: `vim.keymap.set('n', 'n', handler, { buffer = preview_buf })`
- **Why**:
  - ✅ No global pollution
  - ✅ Automatic cleanup on buffer delete
  - ✅ Only active when in Preview window

#### 7. **File Modification Detection** (Future enhancement)

- **Current**: Show warning if line content mismatches
- **Future**: Fuzzy match to find where pattern moved to
- **Priority**: Low (rare edge case)

### Testing Checklist for v0.2.0

- [ ] Focus transfers to Preview on `o`
- [ ] `n/N` navigation works in Preview
- [ ] `q` returns focus to Results
- [ ] Highlights use namespace (verify with `:lua =vim.api.nvim_get_namespaces()`)
- [ ] No highlight conflicts with `/` search
- [ ] Keymaps cleaned up on exit
- [ ] Works with files containing multibyte characters (UTF-8)
- [ ] Cursor positioned at match start, not line start
