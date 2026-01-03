local default_opts = {
  highlight = {
    percent = 3,
  },
  read_only = {
    enabled = true,
    region_text = {
      start = "begin read only",
      ending = "end read only",
    },
  },
}

local M = {
  opts = default_opts,
}

local function is_valid(opts)
  local notify = require("gnattest.utils").notify
  if opts.read_only and opts.read_only.region_text then
    local rt = opts.read_only.region_text
    if type(rt.start) ~= "string" or type(rt.ending) ~= "string" then
      notify(
        "region_text.start and ending must be strings",
        vim.log.levels.ERROR
      )
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
