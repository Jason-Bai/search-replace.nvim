-- lua/search-replace/ui/results.lua
local Menu = require("nui.menu")
local NuiLine = require("nui.line")
local Config = require("search-replace.config")

-- Try to load nvim-web-devicons (optional dependency)
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local M = {}

---Get file icon if devicons is available
---@param filepath string
---@return string icon, string? highlight
local function get_file_icon(filepath)
  if not has_devicons then
    return "", nil
  end

  local icons_config = Config.get("icons")
  if not icons_config or not icons_config.enabled then
    return "", nil
  end

  local filename = vim.fn.fnamemodify(filepath, ":t")
  local ext = vim.fn.fnamemodify(filepath, ":e")
  local icon, hl = devicons.get_icon(filename, ext, { default = true })
  return icon or "", hl
end

---Creates the results menu
---@return table NuiMenu
function M.create_results()
  local initial_lines = {}
  local line = NuiLine()
  line:append("No results found", "Comment")
  table.insert(initial_lines, Menu.item(line, { _is_placeholder = true }))

  local menu = Menu({
    position = "50%",
    size = {
      width = "100%",
      height = "100%",
    },
    border = {
      style = "rounded",
      text = {
        top = " Results (Space: toggle, r: replace, u: undo) ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
    enter = false,
  }, {
    lines = initial_lines,
    max_width = 20,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "<C-c>" },
      submit = { "<Space>" },  -- Only Space for submit, remove <CR>
    },
    on_submit = function(item)
      -- Toggle selection or preview
    end,
    on_change = function(item)
      -- Update preview
    end,
  })

  return menu
end

---Updates the results list
---@param menu table NuiMenu
---@param items table List of { file, match_count, selected }
function M.update_results(menu, items)
  local lines = {}
  local icons_config = Config.get("icons") or {}

  for _, item in ipairs(items) do
    local line = NuiLine()

    -- Selection indicator
    if item.selected then
      line:append(icons_config.selected or "✓", "Special")
      line:append(" ", "Normal")
    else
      line:append(icons_config.unselected or " ", "Comment")
      line:append(" ", "Normal")
    end

    -- File icon (if available)
    local icon, icon_hl = get_file_icon(item.file)
    if icon ~= "" then
      line:append(icon .. " ", icon_hl or "Normal")
    end

    -- Filename and match count
    line:append(item.file, "Directory")
    line:append(" (" .. item.match_count .. ")", "Comment")
    table.insert(lines, Menu.item(line))
  end

  if #lines == 0 then
    local line = NuiLine()
    line:append("No results found", "Comment")
    table.insert(lines, Menu.item(line, { _is_placeholder = true }))
  end

  if menu.tree then
    menu.tree:set_nodes(lines)
    menu.tree:render()
  end
end

return M
