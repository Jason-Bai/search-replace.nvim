-- tests/spec/platform_spec.lua
local platform = require("search-replace.core.platform")

describe("Platform", function()
  it("should detect current platform", function()
    -- This will return the actual platform
    local is_win = platform.is_windows()
    assert.is_boolean(is_win)
  end)

  it("should return path separator", function()
    local sep = platform.path_sep()
    assert.is_true(sep == "/" or sep == "\\")
  end)

  it("should normalize paths", function()
    local normalized = platform.normalize_path("foo/bar/baz")
    assert.is_string(normalized)
    -- Result depends on platform
    if platform.is_windows() then
      assert.are.same("foo\\bar\\baz", normalized)
    else
      assert.are.same("foo/bar/baz", normalized)
    end
  end)

  it("should return rg executable name", function()
    local rg = platform.rg_executable()
    assert.are.same("rg", rg)
  end)

  it("should build command string", function()
    local cmd = platform.build_command("/tmp", "rg", { "--json", "test" })
    assert.is_string(cmd)
    assert.is_true(cmd:find("rg") ~= nil)
  end)
end)
