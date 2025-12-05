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
Results                Preview (Browse Mode)
────────────────────  ─────────────────────────
✓ src/main.lua (3)    📄 src/main.lua:42
  ├─ line 42          ───────────────────────
  ├─ line 58          38: function init()
  └─ line 104         39:   local config = {}
                      40:   -- some code
src/util.lua (2)      41:
  ├─ line 15    →     42:   local search = "TODO" ← 🔍 CURRENT
  └─ line 29          43:   return result
                      44: end
                      45:
                      46: function process()

                      [n: next match | N: prev | q: exit browse]
```

---

## User Experience Flow

### Scenario 1: Browse Before Replace
```
1. User searches "TODO"
2. Results shows 20 files, 100+ matches
3. Press `o` → Preview opens first file at first match
4. Press `n n n` → Browse through TODO comments
5. Press `q` → Return to preview mode
6. Press `Space` in Results → Select files for replacement
7. Press `r` → Execute batch replace
```

### Scenario 2: Quick Review
```
1. User searches "old_api"
2. Press `o` → Enter browse mode
3. Use `n/N` to review several occurrences
4. Decide: "Only need to replace in src/ folder"
5. Press `q`, go to Results, select specific files
6. Press `r` to replace
```

---

## Keyboard Mappings

### Results Window
| Key     | Action                                    |
|---------|-------------------------------------------|
| `o`     | Open file in Preview at match position    |
| `Space` | Toggle file selection (unchanged)         |
| `r`     | Execute replacement (unchanged)           |
| `u`     | Undo last replacement (unchanged)         |

### Preview Window (Browse Mode)
| Key     | Action                                           |
|---------|--------------------------------------------------|
| `n`     | Jump to next match (in current file, then next)  |
| `N`     | Jump to previous match                           |
| `q`     | Exit browse mode, return to preview mode         |
| `Tab`   | Focus back to Results (unchanged)                |

**Future enhancements** (v0.3.0):
- `gg` - Jump to first match (global)
- `G`  - Jump to last match (global)
- `{count}n` - Jump forward N matches
- `/` - Search within current file

---

## Implementation Plan

### Phase 1: v0.2.0 - Basic Browse Mode

#### 1.1 Results Window - Add `o` Key
**File**: `lua/search-replace/init.lua`

```lua
results:map("n", "o", function()
  local line_idx = vim.api.nvim_win_get_cursor(results.winid)[1]
  local item = grouped_files[line_idx]

  if not item or item.type ~= 'match' then
    vim.notify("Select a match to open", vim.log.levels.WARN)
    return
  end

  -- Enter browse mode
  enter_browse_mode(preview, item.file, item.line_number)
end)
```

#### 1.2 Preview Window - Browse Mode State
**File**: `lua/search-replace/core/browse.lua` (new)

```lua
local M = {}

-- State
local browse_state = {
  active = false,
  current_file = nil,
  current_line = nil,
  all_matches = {},  -- All matches in current file
  match_index = 0,   -- Current position in matches list
}

function M.enter(preview_window, file_path, line_number)
  -- Load file content into preview buffer
  -- Highlight current match
  -- Store all matches for this file
  -- Enable n/N navigation
end

function M.next_match()
  -- Move to next match in current file
  -- If at end, jump to next file's first match
end

function M.prev_match()
  -- Move to previous match
end

function M.exit()
  -- Clear highlights
  -- Return to normal preview mode
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

#### 1.4 UI Indicators
**Preview title bar** (dynamic):
```lua
-- Normal preview mode
border.text.top = " Preview "

-- Browse mode
border.text.top = string.format(
  " Browse [%d/%d] - %s:%d (n:next N:prev q:exit) ",
  match_index,
  #all_matches,
  vim.fn.fnamemodify(file_path, ":~:."),
  current_line
)
```

**Results title bar**:
```lua
-- Update to include 'o' key
top = " Results (Space: toggle, o: open, r: replace, u: undo) "
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

**Preview Buffer**:
- Use `vim.api.nvim_buf_set_lines()` to load file content
- Use `vim.api.nvim_buf_add_highlight()` for match highlighting
- Set buffer options: `modifiable = false`, `buftype = 'nofile'`

**Cursor Management**:
```lua
vim.api.nvim_win_set_cursor(preview.winid, { line_number, 0 })
vim.fn.matchadd("IncSearch", search_pattern)  -- Highlight keyword
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
- **Solution**: Only load ±50 lines around match for preview
  ```lua
  local start_line = math.max(1, match_line - 50)
  local end_line = math.min(total_lines, match_line + 50)
  ```

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

| Tool              | Navigation       | Cross-file | Preview |
|-------------------|------------------|------------|---------|
| **Telescope**     | `<C-n>/<C-p>`    | Yes        | Live    |
| **vim quickfix**  | `:cn/:cp`        | Yes        | No      |
| **FZF**           | Arrow keys       | Yes        | Static  |
| **Our plugin**    | `n/N`            | Yes (v0.3) | Live    |

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
- **TBD**: Implementation started (v0.2.0)
- **TBD**: Enhanced navigation (v0.3.0)

---

## Notes

- Keep the core batch-replacement workflow simple and fast
- Browse mode is an **optional enhancement**, not a replacement
- Maintain consistency with Vim's `n/N` navigation pattern
- Prioritize performance: lazy-load file content, virtualize long files
