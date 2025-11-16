local M = {
  tests = {},
}

function M.query_pkg(match)
  if match == nil then
    match = "unit"
  end

  local query_string = '\
                    (STag (Name) @tag\
                          (#any-of? @tag "unit" "test_unit")\
                          (Attribute (Name) \
                                     (AttValue) @value)\
                     )'

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

function M.query_test_info(match)
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

  ------------------
  -- **PACKAGE** --
  ------------------
  local pkg_capture_flag = ""
  local query = M.query_pkg(unit_match)
  for _, node in query:iter_captures(root, buf_id) do
    local text = vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
    if pkg_capture_flag == "unit" then
      filename = text
    elseif
      pkg_capture_flag == "test_unit" and source_files[filename] == nil
    then
      pkg = text
      source_files[filename] = { [pkg] = {} }
    end

    pkg_capture_flag = text
  end

  local subpr_test = {}
  local capture_flag = ""

  -----------------
  -- **SOURCES** --
  -----------------
  for name, file_info in pairs(source_files) do
    for p, _ in pairs(file_info) do
      query = M.query_subpr_by_pkg(p)
      for _, subpr_node in query:iter_captures(root, buf_id) do
        local text =
          vim.treesitter.get_node_text(subpr_node, buf_id):gsub('"', "")
        if capture_flag == "name" then
          subpr_test.name = text
        elseif capture_flag == "line" then
          subpr_test.line = text
        elseif capture_flag == "column" then
          subpr_test.column = text
          table.insert(source_files[name][p], subpr_test)
          subpr_test = {}
        end

        capture_flag = text
      end
      M.tests = vim.deepcopy(source_files)
    end
  end

  -- -- Check the correct number of tests are detected, just for debugging
  -- local count = 0
  -- for _, files in pairs(M.tests) do
  --   for _, t in pairs(files) do
  --     count = count + #t
  --   end
  -- end
  -- print(vim.inspect(count))

  return M.tests
end

local function get_pkg_tests(pkg)
  if next(M.tests) == nil then
    M.get_tests()
  end

  for _, files in pairs(M.tests) do
    for p, tst_pkg in pairs(files) do
      if p == pkg then
        return tst_pkg
      end
    end
  end

  return nil
end

function M.get_tests_by_name(pkg, name)
  if next(M.tests) == nil then
    M.get_tests()
  end

  local tst_pkg = get_pkg_tests(pkg)
  if tst_pkg == nil then
    return nil
  end

  for _, test in pairs(tst_pkg) do
    if test.name == name then
      return test
    end
  end

  return nil
end

return M
