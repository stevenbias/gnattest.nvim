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

function M.get_root_dir()
  return require("gnattest.ada_ls").get_ada_ls().root_dir
end

local function lsp_request(req)
  local client = M.get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local result, err = client:request_sync(req, params, 1000)

  if err or not result or not result.result then
    return nil, err or ("Request '" .. req .. "' failed")
  end

  return vim.islist(result.result) and result.result or { result.result }
end

local function lsp_command(cmd, args)
  local client = M.get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end

  local params = {
    command = cmd,
    arguments = args,
  }
  local result, err =
    client:request_sync("workspace/executeCommand", params, 1000)

  if err or not result or not result.result then
    return nil, err or ("Command '" .. cmd .. "' failed")
  end

  return vim.islist(result.result) and result.result or { result.result }
end

function M.get_symbols()
  return lsp_request("textDocument/documentSymbol")
end

function M.get_declarations()
  return lsp_request("textDocument/declaration")
end

function M.get_src_dirs()
  local src_dirs = lsp_command("als-source-dirs")
  if src_dirs == nil then
    return nil
  end

  local dirs = {}
  for _, dir in pairs(src_dirs) do
    table.insert(dirs, vim.uri_to_fname(dir.uri))
  end
  return dirs
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
