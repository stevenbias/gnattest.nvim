local M = {}

---@class GnattestConfig : table
---@field highlight {percent: number}
---@field read_only {enabled: boolean}
---@field [string] any @Additional configuration options supported by gnattest.

---@param opts GnattestConfig|nil
function M.setup(opts)
  local utils = require("gnattest.utils")
  if not utils.try_require("ada_ls") then
    utils.notify(
      "ada_ls.nvim is required for gnattest to work. Please install ada_ls and try again",
      vim.log.levels.ERROR
    )
    return
  end

  require("gnattest.config").setup(opts)
end

return M
