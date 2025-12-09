-- lua/search-replace/core/builder.lua
local SearchOptions = require("search-replace.core.search_options")

local M = {}

---Builds the arguments for ripgrep
---@param inputs table { search: string, flags: string|nil }
---@return table List of arguments
function M.build_args(inputs)
  -- Base arguments for machine-readable output (regex mode by default)
  local args = { "--json", "--line-number", "--column", "--no-heading" }

  -- Add search options (case sensitivity)
  local search_opts = SearchOptions.get_rg_args()
  for _, opt in ipairs(search_opts) do
    table.insert(args, opt)
  end

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
        -- Use --iglob for case-insensitive glob matching when glob case-insensitive is enabled
        local glob_flag = SearchOptions.is_glob_case_sensitive() and "-g" or "--iglob"
        table.insert(args, glob_flag)
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
