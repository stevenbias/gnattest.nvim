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
  vim.api.nvim_create_autocmd("BufReadPre", {
    pattern = {
      "*.ad[bs]",
    },
    callback = function()
      if opts ~= nil and next(opts) ~= nil then
        error("Options are not supported")
      else
        require("gnattest.read_only").setup(M.opts)
        require("gnattest.ada_ls").setup()
      end
    end,
  })
end

return M
