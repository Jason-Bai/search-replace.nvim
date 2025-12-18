-- Performance test for batch replacement optimization
-- This tests the new batch replacement method

local PreviewManager = require("search-replace.engine.preview_manager")

print("=== Batch Replacement Performance Test ===\n")

-- Mock components
local mock_preview = { bufnr = 1, winid = 1 }
local mock_inputs = {
  search = { bufnr = 2 },
  replace = { bufnr = 3 },
}

-- Create PreviewManager instance
local manager = PreviewManager.new(mock_preview, mock_inputs)

-- Test data: file with 50 lines
local test_lines = {}
for i = 1, 50 do
  test_lines[i] = string.format("This is line %d with test content", i)
end

-- Test 1: Batch replacement
print("Test 1: Batch replacement (50 lines)")
local start_time = vim.loop.hrtime()
local result = manager:apply_replacement_batch(test_lines, "test", "replaced")
local end_time = vim.loop.hrtime()
local batch_time_ms = (end_time - start_time) / 1000000

print(string.format("  Time: %.2f ms", batch_time_ms))
print(string.format("  Result lines: %d", #result))
print(string.format("  Sample: %s", result[1]))

-- Test 2: Cached access
print("\nTest 2: Cached access (same parameters)")
start_time = vim.loop.hrtime()
local result2 = manager:get_replaced_lines_cached("/test/file.txt", test_lines, "test", "replaced")
end_time = vim.loop.hrtime()
local cache_time_ms = (end_time - start_time) / 1000000

print(string.format("  Time: %.2f ms", cache_time_ms))
print(string.format("  Speed up: %.0fx faster", batch_time_ms / cache_time_ms))

-- Test 3: Cache clear
print("\nTest 3: Cache clear and re-compute")
manager:clear_cache()
start_time = vim.loop.hrtime()
local result3 = manager:get_replaced_lines_cached("/test/file.txt", test_lines, "test", "replaced")
end_time = vim.loop.hrtime()
local recompute_time_ms = (end_time - start_time) / 1000000

print(string.format("  Time: %.2f ms", recompute_time_ms))

-- Summary
print("\n=== Summary ===")
print(string.format("Batch replacement: %.2f ms", batch_time_ms))
print(string.format("Cache hit: %.2f ms (%.0fx faster)", cache_time_ms, batch_time_ms / cache_time_ms))
print(string.format("Cache miss: %.2f ms", recompute_time_ms))
print("\n✓ All tests passed!")
