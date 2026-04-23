local M = {}

---@class GnattestConfig : table
---@field highlight {percent: number}
---@field read_only {enabled: boolean}
---@field [string] any @Additional configuration options supported by gnattest.

---@param opts GnattestConfig|nil
function M.setup(opts)
  local utils = require("gnattest.utils")

  require("gnattest.config").setup(opts)
  require("gnattest.read_only").setup()

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("AdaLSPAttach", { clear = true }),
    pattern = {
      "*.ad[bs]",
    },
    callback = function(args)
      vim.defer_fn(function()
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= "ada_ls" then
          return
        end

        if not utils.try_require("ada_ls") then
          utils.notify(
            "ada_ls.nvim is required for gnattest to work. Please install ada_ls and try again",
            vim.log.levels.ERROR
          )
          return
        end

        require("gnattest.ada_ls").setup()
      end, 100)
    end,
  })
end

return M
