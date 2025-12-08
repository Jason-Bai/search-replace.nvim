-- tests/spec/browse_spec.lua
local Browse = require("search-replace.core.browse")

describe("Browse Mode", function()
  it("should load without errors", function()
    assert.is_not_nil(Browse)
    assert.is_function(Browse.enter)
    assert.is_function(Browse.exit)
    assert.is_function(Browse.next_match)
    assert.is_function(Browse.prev_match)
    assert.is_function(Browse.is_active)
  end)

  it("should not be active initially", function()
    assert.is_false(Browse.is_active())
  end)

  -- More comprehensive tests would require mocking NUI components
  -- For now, we just verify the module loads and has the expected API
end)
