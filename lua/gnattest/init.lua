local M = {}

---@class GnattestConfig : table
---@field highlight {percent: number}
---@field read_only {enabled: boolean}
---@field [string] any @Additional configuration options supported by gnattest.

---@param opts GnattestConfig|nil
function M.setup(opts)
  require("gnattest.config").setup(opts)
end

return M
