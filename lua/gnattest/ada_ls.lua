local utils = require("gnattest.utils")

local M = {}

function M.get_ada_ls()
  local clients = vim.lsp.get_clients({ name = "ada" })
  if not clients or #clients == 0 then
    require("gnattest.utils").notify(
      "Ada LSP client not found",
      vim.log.levels.WARN
    )
    return nil
  else
    return clients[1]
  end
end

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
        local config = {
          ada = {
            projectFile = gnattest_dir .. "/harness/test_driver.gpr",
          },
        }
        client:notify("workspace/didChangeConfiguration", { settings = config })
      else
        require("gnattest.utils").notify(
          "Ada LSP client not found",
          vim.log.levels.WARN
        )
      end
    end,
  })
end

return M
