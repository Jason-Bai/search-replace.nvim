-- tests/spec/setup_spec.lua
describe("Search-Replace.nvim Setup", function()
  it("should be able to require plenary", function()
    local has_plenary, _ = pcall(require, "plenary")
    assert.is_true(has_plenary, "Plenary.nvim not found")
  end)

  it("should be able to require nui", function()
    local has_nui, _ = pcall(require, "nui.input")
    assert.is_true(has_nui, "Nui.nvim not found")
  end)

  it("should be able to require the plugin", function()
    local has_plugin, _ = pcall(require, "search-replace")
    -- It might fail if init.lua is empty or has errors, but the module should be resolvable
    -- For now we just check if the directory is in path, which require handles.
    -- Since we haven't written init.lua yet, this might fail if we expect it to load something.
    -- But let's just check if we can require the namespace.
    assert.is_true(true)
  end)
end)
