-- tests/spec/state_spec.lua
local state = require("search-replace.core.state")

describe("State Management", function()
  before_each(function()
    state.reset()
  end)

  it("should initialize with empty results", function()
    assert.are.same({}, state.get_results())
  end)

  it("should set results and default to all selected", function()
    local items = {
      { file = "a.lua", line_number = 1 },
      { file = "b.lua", line_number = 2 },
    }
    state.set_results(items)

    assert.are.same(items, state.get_results())
    assert.is_true(state.is_selected(1))
    assert.is_true(state.is_selected(2))
  end)

  it("should toggle selection", function()
    local items = { { file = "a.lua" } }
    state.set_results(items)

    state.toggle_selection(1)
    assert.is_false(state.is_selected(1))

    state.toggle_selection(1)
    assert.is_true(state.is_selected(1))
  end)

  it("should get selected items only", function()
    local items = {
      { file = "a.lua", id = 1 },
      { file = "b.lua", id = 2 },
      { file = "c.lua", id = 3 },
    }
    state.set_results(items)
    state.toggle_selection(2) -- Deselect b.lua

    local selected = state.get_selected_items()
    assert.are.same(2, #selected)
    assert.are.same(1, selected[1].id)
    assert.are.same(3, selected[2].id)
  end)
end)
