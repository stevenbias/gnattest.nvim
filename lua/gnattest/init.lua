local default_opts = {
  -- Region marker text (without comment syntax)
  region_text = {
    start = "begin read only",
    ending = "end read only",
  },
}

local M = {
  opts = default_opts,
}

function M.setup(opts)
  local utils = require("gnattest.utils")
  vim.api.nvim_create_autocmd("BufReadPre", {
    pattern = {
      utils.gnattest_pattern .. "*.ad[bs]",
    },
    callback = function()
      if next(opts) ~= nil then
        error("Options are not supported")
      else
        require("gnattest.read_only").setup(M.opts)
        require("gnattest.ada_ls").setup()
      end
    end,
  })
end

return M
