local M = {}

function M.get_subprogram_name()
  local client = require("gnattest.ada_ls").get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local result, err =
    client:request_sync("textDocument/documentSymbol", params, 1000)

  if err or not result or not result.result then
    return nil, err or "No symbol found"
  end

  local lnum = vim.fn.getpos(".")[2]
  local symbols = result.result

  for _, symbol in ipairs(symbols) do
    for _, child in ipairs(symbol.children) do
      if child.alsIsAdaProcedure == true then
        -- print(vim.inspect(child))
        local range = child.range or child.locations.range
        if range.start.line + 1 <= lnum and lnum <= range["end"].line then
          return child.name
        end
      end
    end
  end

  return nil
end

function M.get_declaration()
  local client = require("gnattest.ada_ls").get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local result, err =
    client:request_sync("textDocument/declaration", params, 1000)

  if err or not result or not result.result then
    return nil, err or "No declaration found"
  end

  local locations = vim.islist(result.result) and result.result
    or { result.result }
  local definitions = {}

  for _, loc in ipairs(locations) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetRange

    table.insert(definitions, {
      filepath = vim.uri_to_fname(uri),
      line = range.start.line + 1,
      column = range.start.character,
      end_line = range["end"].line + 1,
      end_column = range["end"].character,
    })
  end

  return definitions
end

function M.get_gnattest_info_on_cursor()
  local utils = require("gnattest.utils")
  local xml_info = require("gnattest.xml").get_xml_info()

  if next(xml_info) == nil then
    M.get_xml_info()
  end

  local lnum = vim.fn.getpos(".")[2]
  local filename = utils.get_filename()
  local subpr_test
  local search_file_flag = false

  if utils.is_gnattest_file() then
    search_file_flag = true
    subpr_test = M.get_subprogram_name()
    if subpr_test == nil then
      return nil
    end
  else
    local declaration_info = M.get_declaration()[1]
    if declaration_info == nil then
      return nil
    end
    lnum = declaration_info.line
    filename = vim.fs.basename(declaration_info.filepath)
  end

  for f, file_info in pairs(xml_info) do
    for _, pkg_info in pairs(file_info) do
      for _, info in pairs(pkg_info) do
        if not search_file_flag then
          if
            vim.fn.match(f, filename) == 0
            and lnum == tonumber(info.source.line)
          then
            return { [f] = info }
          end
        elseif vim.fn.match(info.test.name, subpr_test) ~= -1 then
          return { [f] = info }
        end
      end
    end
  end

  return nil
end

function M.switch_subprogram()
  local utils = require("gnattest.utils")
  local info = M.get_gnattest_info_on_cursor()
  if info == nil then
    return nil
  end

  local client = require("gnattest.ada_ls").get_ada_ls()
  if not client then
    return nil, "Ada LSP client not found"
  end

  local line, column, file

  for filename, file_info in pairs(info) do
    if utils.is_gnattest_file() then
      file = client.root_dir .. "/src/" .. filename
      line = tonumber(file_info.source.line)
      column = tonumber(file_info.source.column)
    else
      file = client.root_dir .. "/obj/gnattest/tests/" .. file_info.test.file
      line = tonumber(file_info.test.line)
      column = tonumber(file_info.test.column)
    end
    vim.cmd("edit " .. file)
    local pos = { line, column }
    vim.api.nvim_win_set_cursor(0, pos)
  end
end

return M
