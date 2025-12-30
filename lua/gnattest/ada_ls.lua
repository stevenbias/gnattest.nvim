local utils = require("gnattest.utils")

local M = {
  root_dir = "",
  prj_file = "",
  src_dirs = {},
  obj_dir = "",
  harness_dir = "",
  tests_dir = "",
}

local function init_module()
  M.root_dir = M.get_root_dir()
  M.prj_file = M.get_prj_file()
  M.src_dirs = M.get_src_dirs()
  M.obj_dir = M.get_obj_dir()
  M.harness_dir = M.get_harness_dir()
  M.tests_dir = M.get_tests_dir()
end

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
  if M.root_dir ~= "" then
    return M.root_dir
  end

  if M.get_ada_ls() ~= nil then
    M.root_dir = M.get_ada_ls().root_dir
  end
  return M.root_dir
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

function M.get_prj_file()
  if utils.is_gnattest_file() or M.prj_file ~= "" then
    return M.prj_file
  end

  local cmd = lsp_command("als-project-file")
  if cmd ~= nil and next(cmd) ~= nil then
    M.prj_file = vim.uri_to_fname(cmd[1])
  end
  return M.prj_file
end

function M.get_src_dirs()
  if next(M.src_dirs) ~= nil then
    return M.src_dirs
  end

  local src_dirs = lsp_command("als-source-dirs")
  if src_dirs == nil then
    return nil
  end

  local dirs = {}
  for _, dir in pairs(src_dirs) do
    table.insert(dirs, vim.uri_to_fname(dir.uri))
  end
  M.src_dirs = dirs
  return dirs
end

function M.get_obj_dir()
  if M.obj_dir ~= "" then
    return M.obj_dir
  end

  local cmd = lsp_command("als-object-dir")
  if cmd ~= nil and next(cmd) ~= nil then
    M.obj_dir = cmd[1]
  end
  return M.obj_dir
end

function M.get_harness_dir()
  if M.harness_dir ~= "" then
    return M.harness_dir
  end

  local harness_dir = lsp_command(
    "als-get-project-attribute-value",
    { { attribute = "Harness_Dir", pkg = "Gnattest", index = "" } }
  )

  if harness_dir == nil then
    return M.get_obj_dir() .. "/gnattest/harness"
  else
    M.harness_dir = M.get_obj_dir() .. "/" .. harness_dir[1]
    return M.harness_dir
  end
end

-- TODO: 'Tests_Root' attribute is not supported!
function M.get_tests_dir()
  if M.tests_dir ~= "" then
    return M.tests_dir
  end

  local tests_dir = lsp_command(
    "als-get-project-attribute-value",
    { { attribute = "Tests_Dir", pkg = "Gnattest", index = "" } }
  )

  if tests_dir ~= nil then
    M.tests_dir = M.get_obj_dir() .. "/" .. tests_dir[1]
    return M.tests_dir
  else
    return M.get_obj_dir() .. "/" .. "gnattest/tests"
  end
end

local function switch_prj(prj)
  if not utils.is_gnattest_file() then
    return
  end

  local client = M.get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end
  local config = {
    ada = {
      projectFile = prj,
    },
  }
  client:notify("workspace/didChangeConfiguration", { settings = config })
end

function M.switch_to_source()
  switch_prj(M.get_prj_file())
end

function M.switch_to_tests()
  switch_prj(M.get_harness_dir() .. "/test_driver.gpr")
end

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    pattern = {
      "*.ad[bs]",
    },
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client ~= nil and client.name == "ada" then
        init_module()
        utils.set_gnattest_pattern()
        if utils.is_gnattest_file() then
          M.switch_to_tests()
        end
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
