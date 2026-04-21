local utils = require("gnattest.utils")

local M = {
  is_init = false,
  root_dir = "",
  prj_file = "",
  src_dirs = {},
  obj_dir = "",
  harness_dir = "",
  tests_dir = "",
}

local function init_module()
  if M.is_init then
    return
  end

  M.is_init = true
  M.root_dir = M.get_root_dir()
  M.prj_file = M.get_prj_file()
  M.src_dirs = M.get_src_dirs()
  M.obj_dir = M.get_obj_dir()
  M.harness_dir = M.get_harness_dir()
  M.tests_dir = M.get_tests_dir()
  utils.set_gnattest_pattern()
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
  if M.obj_dir ~= "" then
    return M.obj_dir
  end
  local obj_dir = require("ada_ls.lsp_cmd").get_obj_dir()
  if obj_dir ~= nil then
    return obj_dir[1]
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

  local tests_dir = require("ada_ls.lsp_cmd").send_command(
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
  local client = M.get_ada_ls()
  if not client then
    return nil, "Ada Language Server not found"
  end
  local config = {
    ada = {
      projectFile = prj,
    },
  }
  client:notify("workspace/didChangeConfiguration", { settings = config })
end

function M.get_subprogram_name_from_line(lnum)
  local symbols = require("gnattest.ada_ls").get_symbols()
  if not symbols then
    return nil
  end

  for _, symbol in ipairs(symbols) do
    for _, child in ipairs(symbol.children) do
      local range = child.range or child.selectionRange
      if range.start.line + 1 == lnum then
        return child.name
      elseif range.start.line + 1 < lnum and lnum <= range["end"].line + 1 then
        range = child.selectionRange
        return child.name,
          {
            tonumber(range.start.line + 1),
            tonumber(range.start.character + 1),
          }
      end
    end
  end

  return nil
end

function M.switch_to_source()
  switch_prj(M.get_prj_file())
end

function M.switch_to_tests()
  switch_prj(M.get_harness_dir() .. "/test_driver.gpr")
end

function M.setup()
  init_module()
  if utils.is_gnattest_file() then
    M.switch_to_tests()
  end
end

return M
