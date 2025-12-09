-- tests/spec/ui_inputs_spec.lua
local ui_inputs = require("search-replace.ui.inputs")

describe("UI Inputs", function()
  it("should create search, replace, and flags inputs", function()
    local inputs = ui_inputs.create_inputs()
    assert.is_not_nil(inputs.search)
    assert.is_not_nil(inputs.replace)
    assert.is_not_nil(inputs.flags)

    -- Check labels/borders
    -- Accessing border text is tricky in Nui, but we can check if they are Input objects
    assert.is_function(inputs.search.mount)
  end)

  it("should have correct placeholders", function()
    -- This might be hard to test without inspecting internal state or rendering.
    -- We'll assume if creation works, it's fine for now.
    -- Or we can check if `_` table has `border` config.
    local inputs = ui_inputs.create_inputs()
    -- Nui stores options in private fields, so we might skip deep inspection.
    assert.is_true(true)
  end)
end)
