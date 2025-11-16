local M = {
  tests = {},
}

function M.query_pkg(capture_name, match)
  if match == nil then
    match = "unit"
  end

  -- local query_string = "\
  --   (element\
  --     (STag (Name) @tag (#eq? @tag " .. match .. "))\
  --   )@" .. capture_name
  local query_string = '\
                    (STag (Name) @tag\
                          (#any-match? @tag "unit" "test_unit")\
                          (Attribute (Name) \
                                     (AttValue) @value)\
                     )'

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
    match = {
      '"tested"',
      '"test_unit"',
    }
  end

  local query_string = "\
            (STag (Name) @node\
                  (#any-of? @node " .. table.concat(match, " ") .. ")\
                  (Attribute (Name) @string\
                             (AttValue) @" .. capture_name .. ")\
            )"
  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_subpr_by_pkg(pkg)
  if pkg == nil then
    pkg = ""
  end

  local query_string = '\
                    (element\
                      (STag (Name)\
                            (Attribute (Name)\
                                       (AttValue) @pkg)\
                            (#eq? @pkg "\\"' .. pkg .. '\\"")\
                      )\
                      (content\
                        (element\
                          (STag (Name)\
                                (Attribute (Name) @string\
                                           (AttValue) @val)\
                          )\
                        )\
                      )\
                    )'

  -- local query_string = "\
  --                   (element\
  --                     (STag (Name)\
  --                           (Attribute (Name)\
  --                                      (AttValue) @pkg)\
  --                     )\
  --                   )"

  -- print(query_string)
  -- local query_string = "\
  --               (element\
  --                 (STag (Name)\
  --                       (Attribute (Name) @string\
  --                                  (AttValue) @pkg)\
  --                 )\
  --                 (content\
  --                   (element\
  --                     (EmptyElemTag (Name)\
  --                       (Attribute (Name) @string\
  --                                  (AttValue) @test)\
  --                     )\
  --                   )\
  --                   (element\
  --                     (STag (Name)\
  --                           (Attribute (Name) @string\
  --                                      (AttValue) @val)\
  --                     )\
  --                   )\
  --                 )\
  --               )"

  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_test_info(capture_name, match)
  if match == nil then
    match = {
      '"tested"',
      '"test_unit"',
    }
  end

  -- local query_string = "\
  --           (STag (Name) @node\
  --                 (#any-of? @node " .. table.concat(match, " ") .. ")\
  --                 (Attribute (Name) @string\
  --                            (AttValue) @" .. capture_name .. ")\
  --           )"

  local query_string = '\
                      (element\
                        (STag (Attribute (AttValue) @subpr))\
                        (#eq? @subpr "Next_Turn")\
                        (content\
                          (element\
                            (content\
                              (element\
                                (EmptyElemTag (Name)\
                                  (Attribute (Name) @string\
                                             (AttValue) @test)\
                                )\
                              )\
                            )\
                          )\
                        )\
                      )'

  return vim.treesitter.query.parse("xml", query_string)
end

local function create_xml_buf()
  local xml_file = vim.fs.find(function(name)
    return name:match(".*%gnattest.xml$")
  end)[1]
  xml_file = vim.fn.readfile(xml_file)

  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, xml_file)

  return buf_id
end

function M.get_tests()
  if next(M.tests) ~= nil then
    return M.tests
  end

  local buf_id = create_xml_buf()
  local root = vim.treesitter.get_parser(buf_id, "xml"):parse()[1]:root()

  local filename = ""
  local pkg = ""
  local source_files = {}

  --------------
  -- **UNIT** --
  --------------
  local unit_match = "unit"
  local unit_capture_name = unit_match
  local query = M.query_pkg(unit_capture_name, unit_match)

  ------------------
  -- **PACKAGE** --
  ------------------
  local pkg_capture_flag = ""
  for _, node in query:iter_captures(root, buf_id) do
    local text = vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
    if pkg_capture_flag == "unit" then
      filename = text
    elseif pkg_capture_flag == "test_unit" then
      pkg = text
      source_files[filename] = { [pkg] = {} }
    end

    -- local src_file_capture_name = "src_file"
    -- query = M.query_src_file(src_file_capture_name)
    -- for _, n in query:iter_captures(node, buf_id) do
    --   text = vim.treesitter.get_node_text(n, buf_id):gsub('"', "")
    --   print(text)
    --   if text ~= "source_file" then
    --     filename = text
    --     -----------------
    --     -- **SOURCES** --
    --     -----------------
    pkg_capture_flag = text
  end
  -- print(vim.inspect(source_files))
  local subpr_test = {}
  local capture_flag = ""
  local subpr_capture_name = "subpr"

  for filename, file_info in pairs(source_files) do
    for pkg, info in pairs(file_info) do
      -- print(filename)
      -- print(vim.inspect(pkg))
      query = M.query_subpr_by_pkg(pkg)
      for _, subpr_node in query:iter_captures(root, buf_id) do
        local text = vim.treesitter.get_node_text(subpr_node, buf_id)
        -- print(text)

        -- if capture_flag == "target_file" then
        --   pkg = text
        -- elseif capture_flag == "name" then
        if capture_flag == "name" then
          subpr_test.name = text
        elseif capture_flag == "line" then
          subpr_test.line = text
        elseif capture_flag == "column" then
          subpr_test.column = text
          -- subpr_test.pkg = pkg
          source_files[filename][pkg] = subpr_test
          subpr_test = {}
        end

        capture_flag = text
      end
      M.tests = vim.deepcopy(source_files)
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

function M.get_tests_by_name(pkg, name)
  if next(M.tests) == nil then
    M.get_tests()
  end

  for _, files in pairs(M.tests) do
    for filename, test in pairs(files) do
      if test.pkg == pkg and test.name == name then
        test.filename = filename
        return test
      end
    end
  end

  return nil
end

return M
