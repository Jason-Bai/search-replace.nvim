-- tests/spec/diff_spec.lua
local diff = require("search-replace.core.diff")

describe("Diff Logic", function()
  it("should generate diff lines", function()
    local original = "local foo = bar"
    local replacement = "local baz = bar"
    local lines = diff.generate_diff(original, replacement)

    -- Expected:
    -- - local foo = bar
    -- + local baz = bar
    assert.are.same(2, #lines)
    assert.is_not_nil(lines[1]:match("^-"))
    assert.is_not_nil(lines[2]:match("^+"))
  end)

  it("should handle empty replacement (deletion)", function()
    local original = "local foo = bar"
    local replacement = ""
    local lines = diff.generate_diff(original, replacement)

    -- Expected:
    -- - local foo = bar
    -- +
    assert.are.same(2, #lines)
    assert.is_not_nil(lines[1]:match("^-"))
    assert.is_not_nil(lines[2]:match("^+"))
  end)
end)
