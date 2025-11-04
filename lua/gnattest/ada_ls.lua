local utils = require("gnattest.utils")

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local _, j = string.find(utils.get_bufdir(), "gnattest")
      local gnattest_dir = string.sub(utils.get_bufdir(), 1, j)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client.name == "ada" then
        local ada_ls = assert(vim.lsp.get_clients({ name = "ada" })[1])
        local config = {}
        config["projectFile"] = gnattest_dir .. "/harness/test_driver.gpr"
        config = { ada = config }
        ada_ls.notify("workspace/didChangeConfiguration", { settings = config })
      end
    end,
  })
end

return M
