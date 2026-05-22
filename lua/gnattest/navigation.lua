local M = {}

local function get_declaration_info()
  local decla_info = require("gnattest.ada_ls").get_declarations()
  if not decla_info then
    return nil
  end
  local declarations = {}

  for _, loc in ipairs(decla_info) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetRange

    if range and range.start and range["end"] then
      table.insert(declarations, {
        filepath = vim.uri_to_fname(uri),
        line = range.start.line + 1,
        column = range.start.character,
        end_line = range["end"].line + 1,
        end_column = range["end"].character,
      })
    end
  end

  return declarations
end

function M.switch_subprogram()
  local utils = require("gnattest.utils")
  local filename, _, info =
    require("gnattest.xml").get_gnattest_info_on_cursor()
  if info == nil then
    return nil
  end

  local als = require("gnattest.ada_ls")
  local line, column, file

  if utils.is_gnattest_file() then
    local src_dirs = als.get_src_dirs()
    if not src_dirs then
      return nil
    end
    file = utils.find_file(filename, src_dirs)
    if not file then
      return nil
    end
    line = tonumber(info.source.line)
    column = tonumber(info.source.column)
    als.switch_to_source()
  else
    file = als.get_tests_dir() .. "/" .. info.tests[1].file
    line = tonumber(info.tests[1].line)
    column = tonumber(info.tests[1].column)
    als.switch_to_tests()
  end

  vim.cmd("edit " .. file)
  local pos = { line, column }
  vim.api.nvim_win_set_cursor(0, pos)
end

-- Test-specific exports - only exposed in test mode
if os.getenv("GNATTEST_TEST_MODE") then
  M._get_declaration_info = get_declaration_info
end

return M
