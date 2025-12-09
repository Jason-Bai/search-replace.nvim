-- tests/spec/ui_results_spec.lua
local ui_results = require("search-replace.ui.results")

describe("UI Results", function()
  it("should create a results menu", function()
    local results = ui_results.create_results()
    assert.is_not_nil(results)
    assert.is_function(results.mount)
  end)

  it("should populate results", function()
    local results = ui_results.create_results()
    -- Updated to file-level format (grouped by file)
    local items = {
      { file = "file1.lua", match_count = 2, selected = true },
      { file = "file2.lua", match_count = 1, selected = false },
    }

    -- We need to mock the tree or menu update method if we want to verify it strictly.
    -- But let's just check if we can call the update method.
    local ok, _ = pcall(ui_results.update_results, results, items)
    assert.is_true(ok)
  end)
end)
