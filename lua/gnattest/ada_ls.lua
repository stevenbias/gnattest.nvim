local utils = require("gnattest.utils")

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = {
      utils.gnattest_pattern .. "*.ad[bs]",
    },
    callback = function(ev)
      local path = utils.get_bufdir()
      local _, j = string.find(path, "gnattest")
      local gnattest_dir = string.sub(path, 1, j)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client ~= nil and client.name == "ada" then
        local clients = vim.lsp.get_clients({ name = "ada" })
        if not clients or #clients == 0 then
          require("gnattest.utils").notify(
            "Ada LSP client not found",
            vim.log.levels.WARN
          )
          return
        end
        local ada_ls = clients[1]
        local config = {
          ada = {
            projectFile = gnattest_dir .. "/harness/test_driver.gpr",
          },
        }
        ada_ls:notify("workspace/didChangeConfiguration", { settings = config })
      end
    end,
  })
end

return M
