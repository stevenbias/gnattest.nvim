local default_opts = {
  read_only = {
    region_text = {
      start = "begin read only",
      ending = "end read only",
    },
  },
}

local M = {
  opts = default_opts,
}

function M.get()
  return M.opts
end

function M.set(opts)
  M.opts = vim.tbl_deep_extend("force", default_opts, opts or {})
end

return M
