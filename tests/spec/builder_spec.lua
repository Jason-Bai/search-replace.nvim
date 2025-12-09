-- tests/spec/builder_spec.lua
local builder = require("search-replace.core.builder")

describe("Command Builder", function()
  it("should build basic rg command", function()
    local inputs = { search = "query" }
    local cmd = builder.build_args(inputs)
    -- Base args: rg --json --line-number --column --no-heading query
    -- Note: --fixed-strings is no longer included (regex mode by default)
    
    local expected_base = { "--json", "--line-number", "--column", "--no-heading" }
    for _, flag in ipairs(expected_base) do
      assert.is_true(vim.tbl_contains(cmd, flag))
    end
    assert.is_true(vim.tbl_contains(cmd, "query"))
  end)

  it("should parse include and exclude paths correctly", function()
    local inputs = {
      search = "foo",
      flags = "src/, !tests/"
    }
    local args = builder.build_args(inputs)
    
    -- Check for -g src/ and -g !tests/
    -- We need to find the index of -g and check next element
    local glob_indices = {}
    for i, v in ipairs(args) do
      if v == "-g" then table.insert(glob_indices, i) end
    end
    
    assert.are.same(2, #glob_indices)
    -- Note: directories ending with / are auto-appended with ** for proper matching
    assert.are.same("src/**", args[glob_indices[1] + 1])
    assert.are.same("!tests/**", args[glob_indices[2] + 1])
  end)

  it("should handle mixed inputs with extra spaces", function()
    local inputs = { search = "foo", flags = "  *.lua , !node_modules/  " }
    local args = builder.build_args(inputs)
    
    local glob_indices = {}
    for i, v in ipairs(args) do
      if v == "-g" then table.insert(glob_indices, i) end
    end
    
    assert.are.same(2, #glob_indices)
    assert.are.same("*.lua", args[glob_indices[1] + 1])
    -- Note: directories ending with / are auto-appended with **
    assert.are.same("!node_modules/**", args[glob_indices[2] + 1])
  end)
  
  it("should handle empty flags", function()
    local inputs = { search = "foo", flags = "" }
    local args = builder.build_args(inputs)
    assert.is_false(vim.tbl_contains(args, "-g"))
  end)
end)
