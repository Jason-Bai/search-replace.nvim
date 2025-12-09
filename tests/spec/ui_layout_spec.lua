-- tests/spec/ui_layout_spec.lua
local Layout = require("nui.layout")
local ui_layout = require("search-replace.ui.layout")

describe("UI Layout", function()
  it("should create a split layout", function()
    local mock_component = {
      mount = function() end,
      unmount = function() end,
      on = function() end,
      map = function() end,
    }
    -- Nui Layout expects objects that can be boxed.
    -- Usually Nui Components (Popup, Input, Menu) work.
    -- We can just require Nui Popup for mocking.
    local Popup = require("nui.popup")
    local components = {
      search = Popup({}),
      replace = Popup({}),
      flags = Popup({}),
      results = Popup({}),
      preview = Popup({}),
    }

    local layout = ui_layout.create_layout(components)
    assert.is_not_nil(layout)
    assert.is_function(layout.mount)
  end)

  it("should have left and right components", function()
    local Popup = require("nui.popup")
    local components = {
      search = Popup({}),
      replace = Popup({}),
      flags = Popup({}),
      results = Popup({}),
      preview = Popup({}),
    }
    local layout = ui_layout.create_layout(components)

    layout:mount()
    assert.is_true(layout._.mounted)
    layout:unmount()
  end)
end)
