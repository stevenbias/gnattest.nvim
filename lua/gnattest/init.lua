local M = {}

local function clear()
  require("gnattest.ada_ls").clear()
  require("gnattest.read_only").clear()

  vim.g.loaded_gnattest = nil
  for name, _ in pairs(package.loaded) do
    if name:match("^gnattest") then
      package.loaded[name] = nil
    end
  end
end

local function on_notif_conf_change()
  clear()
  require("gnattest.ada_ls").setup()
  require("gnattest.read_only").setup()
end

---@class GnattestConfig : table
---@field highlight {percent: number}
---@field read_only {enabled: boolean}
---@field [string] any @Additional configuration options supported by gnattest.

---@param opts GnattestConfig|nil
function M.setup(opts)
  local utils = require("gnattest.utils")

  require("gnattest.config").setup(opts)

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
        require("gnattest.read_only").setup()
      end, 100)
    end,
  })

  vim.api.nvim_create_autocmd("LspNotify", {
    group = vim.api.nvim_create_augroup("AdaLSPNotify", { clear = true }),
    pattern = {
      "*.ad[bs]",
    },
    callback = function(ev)
      local method = ev.data.method

      -- do something with the notification
      if method == "workspace/didChangeConfiguration" then
        local project_file = ev.data
          and ev.data.params
          and ev.data.params.settings
          and ev.data.params.settings.ada
          and ev.data.params.settings.ada.projectFile

        if not project_file then
          return
        elseif project_file:match("test_driver.gpr") then
          return -- ignore notifications from the test project
        else
          -- clear and re-setup gnattest when ada_ls sends a
          -- workspace/didChangeConfiguration notification
          on_notif_conf_change()
        end
      end
    end,
  })
end

return M
