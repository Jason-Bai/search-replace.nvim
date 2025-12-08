# Window Auto-Resize Design Notes

## Current Status

**Issue**: Layout does not auto-resize when terminal window size changes.

**Current behavior**:
- Layout size calculated once on mount: `width = "80%", height = "80%"`
- NUI Layout does not listen to VimResized events
- User needs to close and reopen to see adjusted layout

## Decision: Not Implementing Auto-Resize (for now)

### Reasons

1. **Plugin Type**: Floating dialog, not a persistent sidebar
   - User workflow: Open → Use → Close (not kept open during terminal resize)
   - Unlike nvim-tree/neo-tree which are always visible

2. **Industry Standard**: Most floating window plugins don't auto-resize
   - Telescope: No auto-resize
   - Trouble.nvim: No auto-resize
   - Noice.nvim: Has it, but is a notification system (different use case)

3. **Implementation Complexity**:
   - Need to listen to VimResized autocmd
   - Need to unmount and remount entire layout
   - May cause flickering/performance issues
   - Higher maintenance burden

4. **Workaround**: Simple and effective
   - User can press `Esc` and reopen with `<leader>sr`
   - Takes ~1 second, acceptable UX

## Future Implementation (if needed)

**Trigger**: User feedback requesting this feature

**Implementation approach** (reference only):

```lua
-- In init.lua, after layout:mount()

local resize_autocmd = nil

local function handle_resize()
  if not layout or not layout.winid or not vim.api.nvim_win_is_valid(layout.winid) then
    return
  end

  -- Save current state
  local search_content = vim.api.nvim_buf_get_lines(inputs.search.bufnr, 0, -1, false)
  local cursor_pos = vim.api.nvim_win_get_cursor(results.winid)

  -- Unmount and remount
  layout:unmount()
  layout = Layout.create_layout(components)
  layout:mount()

  -- Restore state
  vim.api.nvim_buf_set_lines(inputs.search.bufnr, 0, -1, false, search_content)
  vim.api.nvim_win_set_cursor(results.winid, cursor_pos)
end

-- Register autocmd
resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
  callback = handle_resize,
  desc = "Auto-resize search-replace layout",
})

-- Clean up on close
local original_close = close
close = function()
  if resize_autocmd then
    vim.api.nvim_del_autocmd(resize_autocmd)
  end
  original_close()
end
```

**Issues with this approach**:
1. Flickering during remount
2. May lose focus/cursor position
3. Performance impact on frequent resizes
4. Increased code complexity

## Alternative: Responsive Size Configuration

Allow users to configure min/max sizes:

```lua
-- config.lua
win_options = {
  width = { min = 120, max = 200, default = "80%" },
  height = { min = 30, max = 60, default = "80%" },
}
```

**Verdict**: Also adds complexity without significant UX benefit.

## Conclusion

**Do not implement auto-resize for v0.1.x - v0.2.x**

Re-evaluate if:
- Multiple users report this as a pain point
- Plugin becomes a persistent sidebar (unlikely)
- Better NUI.nvim API becomes available

---

**References**:
- Telescope issue: https://github.com/nvim-telescope/telescope.nvim/issues/783
- NUI Layout docs: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/layout
