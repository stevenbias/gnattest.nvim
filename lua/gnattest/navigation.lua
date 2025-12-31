local M = {}

local function get_subprogram_name()
  local lnum = vim.fn.getpos(".")[2]
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

local function get_declaration_info()
  local decla_info = require("gnattest.ada_ls").get_declarations()
  if not decla_info then
    return nil
  end
  local declarations = {}

  for _, loc in ipairs(decla_info) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetRange

    table.insert(declarations, {
      filepath = vim.uri_to_fname(uri),
      line = range.start.line + 1,
      column = range.start.character,
      end_line = range["end"].line + 1,
      end_column = range["end"].character,
    })
  end

  return declarations
end

local function get_gnattest_info_on_cursor()
  local utils = require("gnattest.utils")
  local xml_info = require("gnattest.xml").get_xml_info()

  if next(xml_info) == nil then
    return nil
  end

  local filename = utils.get_filename()

  local subr_name, start_pos = get_subprogram_name()
  if subr_name == nil then
    return nil
  end

  local search_file_flag = false

  if utils.is_gnattest_file() then
    search_file_flag = true
  else
    if start_pos ~= nil then
      vim.api.nvim_win_set_cursor(0, start_pos)
    end
    local declaration_info = get_declaration_info()[1]
    if declaration_info == nil then
      return nil
    end
    filename = vim.fs.basename(declaration_info.filepath)
  end

  for f, file_info in pairs(xml_info) do
    for _, pkg_info in pairs(file_info) do
      for _, info in pairs(pkg_info) do
        if not search_file_flag then
          if
            vim.fn.match(f, filename) == 0
            and vim.fn.match(info.source.name, subr_name) ~= -1
          then
            return { [f] = info }
          end
        elseif vim.fn.match(info.test.name, subr_name) ~= -1 then
          return { [f] = info }
        end
      end
    end
  end

  return nil
end

function M.switch_subprogram()
  local utils = require("gnattest.utils")
  local info = get_gnattest_info_on_cursor()
  if info == nil then
    return nil
  end

  local als = require("gnattest.ada_ls")
  local line, column, file

  for filename, file_info in pairs(info) do
    if utils.is_gnattest_file() then
      file = utils.find_file(filename, als.get_src_dirs())
      line = tonumber(file_info.source.line)
      column = tonumber(file_info.source.column)
      als.switch_to_source()
    else
      file = als.get_tests_dir() .. "/" .. file_info.test.file
      line = tonumber(file_info.test.line)
      column = tonumber(file_info.test.column)
      als.switch_to_tests()
    end
    vim.cmd("edit " .. file)
    local pos = { line, column }
    vim.api.nvim_win_set_cursor(0, pos)
  end
end

-- Test-specific exports - only exposed in test mode
if os.getenv("GNATTEST_TEST_MODE") then
  M._get_subprogram_name = get_subprogram_name
  M._get_declaration_info = get_declaration_info
  M._get_gnattest_info_on_cursor = get_gnattest_info_on_cursor
end

return M
