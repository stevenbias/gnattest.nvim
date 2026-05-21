local M = {
  is_init = false,
  root_dir = "",
  prj_file = "",
  src_dirs = {},
  obj_dir = nil,
  harness_dir = "",
  tests_dir = "",
}

local function init_module()
  if M.is_init then
    return
  end

  M.get_prj_file()
  M.is_init = true
end

function M.get_ada_ls()
  return require("ada_ls.utils").get_ada_ls()
end

function M.get_root_dir()
  if M.root_dir ~= "" then
    return M.root_dir
  end

  return require("ada_ls.lsp_cmd").get_root_dir()
end

function M.get_symbols()
  return require("ada_ls.lsp_cmd").get_symbols()
end

function M.get_declarations()
  return require("ada_ls.lsp_cmd").get_declarations()
end

function M.get_prj_file()
  if M.prj_file ~= "" then
    return M.prj_file
  end

  local cmd = require("ada_ls.lsp_cmd").get_prj_file()
  if cmd ~= nil then
    M.prj_file = vim.uri_to_fname(cmd)
  end
  return M.prj_file
end

function M.get_src_dirs()
  if M.src_dirs ~= nil and next(M.src_dirs) ~= nil then
    return M.src_dirs
  end

  local src_dirs = require("ada_ls.lsp_cmd").get_src_dirs()
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
  if M.obj_dir ~= nil then
    return M.obj_dir
  end
  local obj_dir = require("ada_ls.lsp_cmd").get_obj_dir()
  if obj_dir ~= nil then
    M.obj_dir = obj_dir
    return M.obj_dir
  else
    return nil
  end
end

function M.get_harness_dir()
  if M.harness_dir ~= "" then
    return M.harness_dir
  end

  local harness_dir = require("ada_ls.lsp_cmd").send_command(
    "als-get-project-attribute-value",
    { attribute = "Harness_Dir", pkg = "Gnattest", index = "" }
  )

  if harness_dir == nil and harness_dir ~= "" then
    M.harness_dir = M.get_obj_dir() .. "/gnattest/harness"
    return M.harness_dir
  else
    M.harness_dir = M.get_obj_dir() .. "/" .. harness_dir
    return M.harness_dir
  end
end

-- TODO: 'Tests_Root' attribute is not supported!
function M.get_tests_dir()
  if M.tests_dir ~= "" then
    return M.tests_dir
  end

  local tests_dir = require("ada_ls.lsp_cmd").send_command(
    "als-get-project-attribute-value",
    { attribute = "Tests_Dir", pkg = "Gnattest", index = "" }
  )

  if tests_dir ~= nil and tests_dir ~= "" then
    M.tests_dir = M.get_obj_dir() .. "/" .. tests_dir
    return M.tests_dir
  else
    M.tests_dir = M.get_obj_dir() .. "/" .. "gnattest/tests"
    return M.tests_dir
  end
end

local function switch_prj(prj)
  local client = M.get_ada_ls()
  if not client then
    return nil, "Ada Language Server not found"
  end
  local config = {
    ada = {
      projectFile = prj,
    },
  }
  return require("ada_ls.utils").notify_server(
    "workspace/didChangeConfiguration",
    { settings = config }
  )
end

function M.get_subprogram_name_from_line(lnum)
  return require("ada_ls.utils").get_subprogram_name_from_line(lnum)
end

function M.switch_to_source()
  switch_prj(M.get_prj_file())
end

function M.switch_to_tests()
  switch_prj(M.get_harness_dir() .. "/test_driver.gpr")
end

function M.setup()
  init_module()
  if require("gnattest.utils").is_gnattest_file() then
    M.switch_to_tests()
  end
end

return M
