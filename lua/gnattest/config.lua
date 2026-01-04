local default_opts = {
  highlight = {
    percent = 3,
  },
  read_only = {
    enabled = true,
  },
}

local valid_keys = {
  "highlight",
  "read_only",
}

local M = {
  opts = default_opts,
}

local function is_valid(opts)
  if opts == nil then
    return true
  end

  local notify = require("gnattest.utils").notify

  for key in pairs(opts) do
    if not vim.tbl_contains(valid_keys, key) then
      notify("Unknown config field: " .. key, vim.log.levels.ERROR)
      return false
    end
  end

  if opts.highlight and opts.highlight.percent then
    if type(opts.highlight.percent) ~= "number" then
      notify("highlight.percent must be a number", vim.log.levels.ERROR)
      return false
    end
  end

  return true
end

function M.get()
  return M.opts
end

function M.set(opts)
  if is_valid(opts) then
    M.opts = vim.tbl_deep_extend("force", default_opts, opts or {})
  end
end

return M
