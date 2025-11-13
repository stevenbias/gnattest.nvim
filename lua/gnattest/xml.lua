local M = {
  tests = {},
  source_files = {},
}

function M.query_units(capture_name, match)
  if match == nil then
    match = "unit"
  end

  local query_string = "\
    (element\
      (STag (Name) @tag (#eq? @tag " .. match .. "))\
    )@" .. capture_name
  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_src_file(capture_name, match)
  if match == nil then
    match = "source_file"
  end

  local query_string = "\
    (STag\
        ((Attribute ((Name) @tag.attribute)\
        (#eq? @tag.attribute " .. match .. ")\
        (AttValue) @" .. capture_name .. "))\
    )"
  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_subpr(capture_name, match)
  if match == nil then
    match = "tested"
  end

  local query_string = "\
            (STag (Name) @node\
                  (#eq? @node " .. match .. ")\
                  (Attribute (Name) @string\
                             (AttValue) @" .. capture_name .. ")\
            )"

  return vim.treesitter.query.parse("xml", query_string)
end

local function create_xml_buf()
  local xml_file = vim.fs.find(function(name)
    return name:match(".*%gnattest.xml$")
  end)[1]
  xml_file = vim.fn.readfile(xml_file)

  -- Create a new scratch buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, xml_file)

  return buf_id
end

function M.get_tests()
  M.tests = {}

  local buf_id = create_xml_buf()
  local root = vim.treesitter.get_parser(buf_id, "xml"):parse()[1]:root()

  --------------
  -- **UNIT** --
  --------------
  local unit_match = "unit"
  local unit_capture_name = unit_match
  local query = M.query_units(unit_capture_name, unit_match)

  for _, node in query:iter_captures(root, buf_id) do
    ------------------
    -- **FILENAME** --
    ------------------
    local src_file_capture_name = "src_file"
    query = M.query_src_file(src_file_capture_name)
    for _, n in query:iter_captures(node, buf_id) do
      local text = vim.treesitter.get_node_text(n, buf_id)
      if text ~= "source_file" then
        local filename = text:gsub('"', "")
        local subpr_test = {}
        M.source_files = {
          [filename] = {},
        }
        --------------------
        -- **SUBPROGRAM** --
        --------------------
        local captures_flag = ""
        local subpr_capture_name = "subpr"
        query = M.query_subpr(subpr_capture_name)
        for _, subpr_node in query:iter_captures(node, buf_id) do
          text = vim.treesitter.get_node_text(subpr_node, buf_id)

          if captures_flag == "name" then
            subpr_test.name = text:gsub('"', "")
          elseif captures_flag == "line" then
            subpr_test.line = text:gsub('"', "")
          elseif captures_flag == "column" then
            subpr_test.column = text:gsub('"', "")
            table.insert(M.source_files[filename], subpr_test)
            subpr_test = {}
          end

          captures_flag = text:gsub('"', "")
        end
        table.insert(M.tests, M.source_files)
      end
    end
  end

  -- -- Check the correct number of tests are detected, just for debugging
  -- local count = 0
  -- for _, test in pairs(M.tests) do
  --   for _, t in pairs(test) do
  --     count = count + #t
  --   end
  -- end
  -- print(vim.inspect(count))

  return M.tests
end

return M
