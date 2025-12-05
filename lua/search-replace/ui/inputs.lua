-- lua/search-replace/ui/inputs.lua
local Input = require("nui.input")

local M = {}

---Creates the input components
---@return table { search: NuiInput, replace: NuiInput, flags: NuiInput }
function M.create_inputs()
  local search_input = Input({
    position = "50%",
    size = {
      width = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = " Search ",
        top_align = "center",
      },
    },
    enter = false,
  }, {
    prompt = "> ",
    default_value = "",
    on_submit = function(value)
      -- TODO: Trigger search
    end,
  })

  local replace_input = Input({
    position = "50%",
    size = {
      width = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = " Replace ",
        top_align = "center",
      },
    },
    enter = false,
  }, {
    prompt = "> ",
    default_value = "",
    on_submit = function(value)
      -- TODO: Move to flags or list
    end,
  })

  local flags_input = Input({
    position = "50%",
    size = {
      width = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = " Flags / Filter ",
        top_align = "center",
      },
    },
    enter = false,
  }, {
    prompt = "> ",
    default_value = "",
    on_submit = function(value)
      -- TODO: Trigger search with flags
    end,
  })

  return {
    search = search_input,
    replace = replace_input,
    flags = flags_input,
  }
end

return M
