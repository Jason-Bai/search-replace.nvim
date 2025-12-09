-- tests/spec/config_spec.lua
local config = require("search-replace.config")

describe("Configuration", function()
  before_each(function()
    -- Reset to defaults before each test
    config.setup()
  end)

  it("should have default keymap", function()
    assert.are.same("<leader>sr", config.get("keymap"))
  end)

  it("should have default window options", function()
    local win_opts = config.get("win_options")
    assert.are.same(0.8, win_opts.width)
    assert.are.same(0.8, win_opts.height)
  end)

  it("should merge user config with defaults", function()
    config.setup({
      keymap = "<leader>ss",
      win_options = {
        width = 0.6,
      },
    })

    assert.are.same("<leader>ss", config.get("keymap"))
    assert.are.same(0.6, config.get("win_options").width)
    assert.are.same(0.8, config.get("win_options").height) -- Default preserved
  end)

  it("should allow disabling keymap", function()
    config.setup({ keymap = false })
    assert.is_false(config.get("keymap"))
  end)

  it("should support custom rg_options", function()
    config.setup({
      rg_options = { "--hidden", "--no-ignore" },
    })
    local rg_opts = config.get("rg_options")
    assert.are.same(2, #rg_opts)
    assert.is_true(vim.tbl_contains(rg_opts, "--hidden"))
  end)
end)
