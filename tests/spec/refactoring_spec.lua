-- Integration test for refactored search-replace.nvim
-- Tests that the new modular architecture works correctly

describe("Refactored search-replace.nvim", function()
  local sr
  local preview_mgr
  local replace_engine
  local event_handlers

  before_each(function()
    -- Load modules
    sr = require("search-replace")
    preview_mgr = require("search-replace.engine.preview_manager")
    replace_engine = require("search-replace.engine.replacement_engine")
    event_handlers = require("search-replace.engine.event_handlers")
  end)

  describe("Module loading", function()
    it("should load main module", function()
      assert.is_not_nil(sr)
      assert.is_not_nil(sr.setup)
      assert.is_not_nil(sr.open)
      assert.is_not_nil(sr.open_visual)
    end)

    it("should load preview_manager", function()
      assert.is_not_nil(preview_mgr)
      assert.is_not_nil(preview_mgr.new)
    end)

    it("should load replacement_engine", function()
      assert.is_not_nil(replace_engine)
      assert.is_not_nil(replace_engine.new)
    end)

    it("should load event_handlers", function()
      assert.is_not_nil(event_handlers)
      assert.is_not_nil(event_handlers.setup_all)
    end)
  end)

  describe("Setup", function()
    it("should initialize without errors", function()
      assert.has_no.errors(function()
        sr.setup()
      end)
    end)

    it("should accept custom config", function()
      assert.has_no.errors(function()
        sr.setup({
          keymap = "<leader>test",
          win_options = {
            width = 0.9,
            height = 0.9,
          },
        })
      end)
    end)
  end)

  describe("PreviewManager", function()
    it("should create instance", function()
      local mock_preview = { bufnr = 1, winid = 1 }
      local mock_inputs = {
        search = { bufnr = 2 },
        replace = { bufnr = 3 },
      }

      local manager = preview_mgr.new(mock_preview, mock_inputs)
      assert.is_not_nil(manager)
      assert.equals(mock_preview, manager.preview)
    end)

    it("should have required methods", function()
      local mock_preview = { bufnr = 1 }
      local mock_inputs = { search = { bufnr = 2 }, replace = { bufnr = 3 } }
      local manager = preview_mgr.new(mock_preview, mock_inputs)

      assert.is_function(manager.set_grouped_files)
      assert.is_function(manager.get_patterns)
      assert.is_function(manager.apply_replacement)
      assert.is_function(manager.update_preview)
    end)
  end)

  describe("ReplacementEngine", function()
    it("should create instance", function()
      local engine = replace_engine.new()
      assert.is_not_nil(engine)
    end)

    it("should have required methods", function()
      local engine = replace_engine.new()

      assert.is_function(engine.apply_replacement)
      assert.is_function(engine.execute_replacements)
      assert.is_function(engine.restore_from_backup)
      assert.is_function(engine.has_backup)
    end)

    it("should track backup state", function()
      local engine = replace_engine.new()
      assert.is_false(engine:has_backup())
    end)
  end)

  describe("Utility functions", function()
    it("should escape ripgrep regex", function()
      local result = sr.escape_for_rg("test.file*")
      assert.equals("test\\.file\\*", result)
    end)

    it("should escape complex regex", function()
      local result = sr.escape_for_rg("(foo){1,3}[bar]")
      assert.equals("\\(foo\\)\\{1,3\\}\\[bar\\]", result)
    end)
  end)
end)
