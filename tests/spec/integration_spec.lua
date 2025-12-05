-- tests/spec/integration_spec.lua
-- Integration tests for search-replace workflow

local State = require("search-replace.core.state")
local Builder = require("search-replace.core.builder")
local Parser = require("search-replace.core.parser")
local Grouper = require("search-replace.core.grouper")

describe("Integration", function()
  before_each(function()
    State.reset()
  end)

  describe("Search Flow", function()
    it("should build args, parse output, and store results", function()
      -- Build search args
      local args = Builder.build_args({ search = "test", flags = "*.lua" })
      assert.is_true(vim.tbl_contains(args, "test"))
      assert.is_true(vim.tbl_contains(args, "-g"))
      assert.is_true(vim.tbl_contains(args, "*.lua"))

      -- Simulate parsed results
      local mock_results = {
        { file = "file1.lua", line_number = 10, text = "test line 1" },
        { file = "file1.lua", line_number = 20, text = "test line 2" },
        { file = "file2.lua", line_number = 5, text = "another test" },
      }

      -- Store in state
      State.set_results(mock_results)
      local results = State.get_results()
      assert.are.same(3, #results)
    end)

    it("should group results by file", function()
      local mock_results = {
        { file = "a.lua", line_number = 1, text = "foo" },
        { file = "b.lua", line_number = 2, text = "foo" },
        { file = "a.lua", line_number = 3, text = "foo" },
      }

      State.set_results(mock_results)
      local grouped = Grouper.group_by_file(State.get_results())

      assert.are.same(2, #grouped)
      -- First file should be a.lua with 2 matches
      assert.are.same("a.lua", grouped[1].file)
      assert.are.same(2, grouped[1].match_count)
    end)
  end)

  describe("Selection Flow", function()
    it("should manage file selection state", function()
      local mock_results = {
        { file = "file1.lua", line_number = 1, text = "match" },
      }
      State.set_results(mock_results)

      -- Initially all selected
      local selected = State.get_selected_items()
      assert.are.same(1, #selected)

      -- Toggle selection
      State.toggle_selection(1)
      selected = State.get_selected_items()
      assert.are.same(0, #selected)

      -- Toggle back
      State.toggle_selection(1)
      selected = State.get_selected_items()
      assert.are.same(1, #selected)
    end)
  end)

  describe("Replace Flow", function()
    it("should prepare replacement with Lua patterns", function()
      local original = "local foo = create_something()"
      local search_pat = "create"
      local replace_pat = "make"

      local ok, result = pcall(string.gsub, original, search_pat, replace_pat)
      assert.is_true(ok)
      assert.are.same("local foo = make_something()", result)
    end)

    it("should handle complex patterns", function()
      local original = "function test_func()"
      local search_pat = "test_(%w+)"
      local replace_pat = "my_%1"

      local ok, result = pcall(string.gsub, original, search_pat, replace_pat)
      assert.is_true(ok)
      assert.are.same("function my_func()", result)
    end)
  end)
end)
