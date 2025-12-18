-- Manual smoke test for the refactored plugin
-- Run this in Neovim to test basic functionality

-- Test 1: Module loading
print("Test 1: Loading modules...")
local ok1, _ = pcall(require, "search-replace")
local ok2, _ = pcall(require, "search-replace.engine.preview_manager")
local ok3, _ = pcall(require, "search-replace.engine.replacement_engine")
local ok4, _ = pcall(require, "search-replace.engine.event_handlers")

if ok1 and ok2 and ok3 and ok4 then
  print("✓ All modules loaded successfully")
else
  print("✗ Module loading failed")
  print("  init:", ok1)
  print("  preview_manager:", ok2)
  print("  replacement_engine:", ok3)
  print("  event_handlers:", ok4)
end

-- Test 2: Setup function
print("\nTest 2: Setup function...")
local ok, err = pcall(function()
  require("search-replace").setup()
end)

if ok then
  print("✓ Setup completed successfully")
else
  print("✗ Setup failed:", err)
end

-- Test 3: Check if all exports are available
print("\nTest 3: Checking exports...")
local sr = require("search-replace")
local has_setup = type(sr.setup) == "function"
local has_open = type(sr.open) == "function"
local has_open_visual = type(sr.open_visual) == "function"

if has_setup and has_open and has_open_visual then
  print("✓ All required functions exported")
else
  print("✗ Missing exports")
  print("  setup:", has_setup)
  print("  open:", has_open)
  print("  open_visual:", has_open_visual)
end

print("\n" .. string.rep("=", 50))
print("Manual smoke test completed!")
print("To fully test, run :lua require('search-replace').open()")
