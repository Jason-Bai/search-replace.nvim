-- lua/search-replace/ui/layout.lua
local Layout = require("nui.layout")
local Popup = require("nui.popup")

local M = {}

---Creates the main layout for the plugin
---@param components table { search: NuiInput, replace: NuiInput, flags: NuiInput, results: NuiMenu, preview: NuiPopup }
---@return table NuiLayout
function M.create_layout(components)
  local left_panel = Layout.Box({
    Layout.Box(components.search, { size = 3 }),
    Layout.Box(components.replace, { size = 3 }),
    Layout.Box(components.flags, { size = 3 }),
    Layout.Box(components.results, { grow = 1 }), -- Remaining space
  }, { dir = "col", size = "40%" })

  local right_panel = Layout.Box(components.preview, { size = "60%" })

  local layout = Layout(
    {
      position = "50%",
      size = {
        width = "80%",
        height = "80%",
      },
    },
    Layout.Box({
      left_panel,
      right_panel,
    }, { dir = "row" })
  )

  return layout
end

return M
