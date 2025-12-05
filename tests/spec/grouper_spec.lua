-- tests/spec/grouper_spec.lua
local grouper = require("search-replace.core.grouper")

describe("Grouper", function()
  it("should group items by file", function()
    local items = {
      { file = "file1.lua", line_number = 10, text = "match1" },
      { file = "file1.lua", line_number = 20, text = "match2" },
      { file = "file2.lua", line_number = 5, text = "match3" },
    }

    local grouped = grouper.group_by_file(items)

    assert.are.same(2, #grouped)
    assert.are.same("file1.lua", grouped[1].file)
    assert.are.same(2, grouped[1].match_count)
    assert.are.same("file2.lua", grouped[2].file)
    assert.are.same(1, grouped[2].match_count)
  end)

  it("should handle empty input", function()
    local grouped = grouper.group_by_file({})
    assert.are.same(0, #grouped)
  end)

  it("should preserve match details", function()
    local items = {
      { file = "test.lua", line_number = 5, text = "hello world" },
    }

    local grouped = grouper.group_by_file(items)

    assert.are.same(1, #grouped)
    assert.are.same(1, #grouped[1].matches)
    assert.are.same(5, grouped[1].matches[1].line_number)
    assert.are.same("hello world", grouped[1].matches[1].text)
  end)
end)
