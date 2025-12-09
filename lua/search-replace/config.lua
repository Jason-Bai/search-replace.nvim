-- lua/search-replace/config.lua
-- Configuration management for search-replace.nvim

local M = {}

---@class SearchReplaceConfig
---@field keymap string|false Keymap to open search-replace (false to disable)
---@field win_options table Window size options
---@field rg_options table Additional ripgrep options

---Default configuration
---@type SearchReplaceConfig
M.defaults = {
  -- Keymap to open search-replace dialog
  -- Set to false to disable default keymap
  keymap = "<leader>sr",

  -- Window options
  win_options = {
    width = 0.8, -- 80% of editor width
    height = 0.8, -- 80% of editor height
  },

  -- Additional ripgrep options
  rg_options = {
    -- "--hidden",      -- Search hidden files
    -- "--no-ignore",   -- Don't respect .gitignore
  },

  -- Highlight groups for Preview
  highlights = {
    preview_add = "DiffAdd", -- + lines (additions)
    preview_del = "DiffDelete", -- - lines (deletions)
    match = "Search", -- matched text
  },

  -- File icons (requires nvim-web-devicons)
  icons = {
    enabled = true, -- Auto-detect nvim-web-devicons
    selected = "✓",
    unselected = " ",
  },

  -- Search/Replace history
  history = {
    enabled = true,
    max_entries = 50,
  },

  -- Visual selection pre-fill
  visual = {
    enabled = true, -- Enable visual selection pre-fill
    escape_regex = true, -- Auto-escape regex special characters
    auto_focus_replace = true, -- Auto-focus replace field after pre-fill
  },

  -- Realtime search (no Enter required)
  realtime = {
    enabled = true, -- Enable realtime search
    debounce_ms = 300, -- Delay before triggering search
    min_chars = 2, -- Minimum characters to start searching
  },
}

---Current configuration (merged with user config)
---@type SearchReplaceConfig
M.options = {}

---Setup configuration
---@param opts? SearchReplaceConfig User configuration
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

---Get a config value
---@param key string
---@return any
function M.get(key)
  return M.options[key]
end

-- Initialize with defaults
M.setup()

return M
