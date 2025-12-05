-- tests/spec/parser_spec.lua
local parser = require("search-replace.core.parser")

describe("Output Parser", function()
  it("should parse real rg JSON match output", function()
    -- Real rg --json output example
    local json_line = [[{"type":"match","data":{"path":{"text":"lua/search-replace/init.lua"},"lines":{"text":"local M = {}\n"},"line_number":8,"absolute_offset":200,"submatches":[{"match":{"text":"M"},"start":6,"end":7}]}}]]
    
    local parsed = parser.parse_line(json_line)
    
    assert.is_not_nil(parsed)
    assert.are.same("lua/search-replace/init.lua", parsed.file)
    assert.are.same(8, parsed.line_number)
    assert.are.same("local M = {}", parsed.text) -- Should strip newline
    assert.are.same("M", parsed.match)
    assert.are.same(6, parsed.start_col)
    assert.are.same(7, parsed.end_col)
  end)

  it("should ignore begin/end/summary types", function()
    local begin_line = [[{"type":"begin","data":{"path":{"text":"lua/search-replace/init.lua"}}}]];
    local end_line = [[{"type":"end","data":{"path":{"text":"lua/search-replace/init.lua"},"binary_offset":null,"stats":{"elapsed":{"secs":0,"nanos":123456},"searches":1,"searches_with_match":1,"bytes_searched":100,"bytes_printed":200,"matched_lines":1,"matches":1}}}]];
    
    assert.is_nil(parser.parse_line(begin_line))
    assert.is_nil(parser.parse_line(end_line))
  end)

  it("should handle malformed JSON gracefully", function()
    local bad_line = "{ broken json"
    local parsed = parser.parse_line(bad_line)
    assert.is_nil(parsed)
  end)
end)
