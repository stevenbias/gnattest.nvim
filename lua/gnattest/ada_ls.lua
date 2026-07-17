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
    -- Fallback to default obj folder...
    return "obj"
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

-- TODO: 'Tests_Root' attribute is not fully supported!
local function get_tests_dir_att(attribute)
  if M.tests_dir ~= "" then
    return ""
  end
  local tests_dir = require("ada_ls.lsp_cmd").send_command(
    "als-get-project-attribute-value",
    { attribute = attribute, pkg = "Gnattest", index = "" },
    1500
  )
  return tests_dir or ""
end

function M.get_tests_dir()
  local tests_dir = ""
  local tests_root
  local subdir = ""

  -- Check for 'Tests_Root' attribute first, if it exists, use it to construct
  -- the tests directory path
  tests_root = get_tests_dir_att("Tests_Root")
  if tests_root ~= "" then
    M.tests_dir = M.get_obj_dir() .. "/" .. tests_root
  end

  -- If 'Tests_Root' is not set, check for 'Subdir' attribute to construct the
  -- tests directory path
  if M.tests_dir == "" then
    subdir = get_tests_dir_att("Subdir")
  end
  if subdir ~= "" then
    local src_dirs = M.get_src_dirs()
    if src_dirs and src_dirs[2] then
      M.tests_dir = src_dirs[2] .. subdir
    end
  end

  -- If neither 'Tests_Root' nor 'Subdir' is set, check for 'Tests_Dir'
  -- attribute
  if M.tests_dir == "" then
    tests_dir = get_tests_dir_att("Tests_Dir")
  end
  if tests_dir ~= "" then
    M.tests_dir = M.get_obj_dir() .. "/" .. tests_dir
  end

  -- If none of the attributes are set, fallback to default tests directory
  if M.tests_dir == "" then
    M.tests_dir = M.get_obj_dir() .. "/" .. "gnattest/tests"
  end

  return M.tests_dir
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
