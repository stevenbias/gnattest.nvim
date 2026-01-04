local M = {}

---@class GnattestConfig
---@field highlight {percent: number}
---@field read_only {enabled: boolean}

---@param opts GnattestConfig|nil
function M.setup(opts)
  require("gnattest.config").set(opts)
end

return M
