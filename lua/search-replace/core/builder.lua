-- lua/search-replace/core/builder.lua
local M = {}

---Builds the arguments for ripgrep
---@param inputs table { search: string, flags: string|nil }
---@return table List of arguments
function M.build_args(inputs)
  -- Base arguments for machine-readable output
  local args = { "--json", "--line-number", "--column", "--no-heading", "--fixed-strings" }

  -- Add flags (glob patterns)
  if inputs.flags and inputs.flags ~= "" then
    -- Split by comma
    local parts = vim.split(inputs.flags, ",")
    for _, part in ipairs(parts) do
      part = vim.trim(part)
      if part ~= "" then
        -- Auto-append /** to directory paths (ending with /)
        if part:match("/$") and not part:match("%*") then
          part = part .. "**"
        end
        table.insert(args, "-g")
        table.insert(args, part)
      end
    end
  end

  -- Add search query
  if inputs.search then
    table.insert(args, inputs.search)
  end

  return args
end

return M
