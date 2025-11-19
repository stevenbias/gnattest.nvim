local M = {
  tests = {},
}

function M.query_element(match)
  if match == nil then
    match = ""
  end

  local query_string = '\
                    (element\
                        (STag (Name) @tag\
                            (#eq? @tag "' .. match .. '")\
                            (Attribute (Name) @string\
                                (AttValue) @value)\
                        )\
                    )@element'

  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_test_info()
  local query_string = '\
                    (element\
                        (STag (Name) @tag\
                            (#eq? @tag "tested")\
                            (Attribute (Name) @string\
                                (AttValue) @src)\
                        )\
                        (content\
                            (element\
                              (content\
                                (element\
                                  (EmptyElemTag (Name)\
                                                (Attribute (Name) @string\
                                                           (AttValue) @tst)\
                                                )\
                                  )\
                                )\
                            )\
                        )\
                    )'

  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_att_value(match)
  if match == nil then
    match = ""
  end

  local query_string = '\
                    (STag (Name) @tag\
                          (#eq? @tag "' .. match .. '")\
                          (Attribute (Name) @string\
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

  return vim.treesitter.query.parse("xml", query_string)
end

function M.query_test_info_by_subpr(subpr)
  if subpr == nil then
    subpr = ""
  end

  local query_string = '\
                      (element\
                        (STag (Attribute (AttValue) @subpr))\
                        (#eq? @subpr "\\"' .. subpr .. '\\"")\
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

  local source_files = {}

  --------------
  -- **UNIT** --
  --------------
  local filename = ""
  local unit_capture_flag = ""
  local unit_match = "unit"
  local query = M.query_element(unit_match)
  ------------------
  -- **PACKAGE** --
  ------------------
  local pkg = {}
  local pkg_capture_flag = ""
  local pkg_match = "test_unit"
  local pkg_query = M.query_element(pkg_match)
  -----------------
  -- **SOURCES** --
  -----------------
  local test_capture_flag = ""
  local src_info = {}
  local test_info = {}
  local test_query = M.query_test_info()

  for _, unit_node in query:iter_captures(root, buf_id) do
    local unit_text =
      vim.treesitter.get_node_text(unit_node, buf_id):gsub('"', "")
    local pkg_info = {}
    for _, pkg_node in pkg_query:iter_captures(unit_node, buf_id) do
      local pkg_text =
        vim.treesitter.get_node_text(pkg_node, buf_id):gsub('"', "")
      for id, test_node in test_query:iter_captures(pkg_node, buf_id) do
        local test_text =
          vim.treesitter.get_node_text(test_node, buf_id):gsub('"', "")
        local capture_id = test_query.captures[id]
        if capture_id == "src" then
          if test_capture_flag == "name" then
            src_info.name = test_text
          elseif test_capture_flag == "line" then
            src_info.line = test_text
          elseif test_capture_flag == "column" then
            src_info.column = test_text
          end
        elseif capture_id == "tst" then
          if test_capture_flag == "file" then
            test_info.file = test_text
          elseif test_capture_flag == "line" then
            test_info.line = test_text
          elseif test_capture_flag == "column" then
            test_info.column = test_text
          elseif test_capture_flag == "name" then
            test_info.name = test_text
            src_info.test = test_info
            table.insert(pkg_info, src_info)
            src_info = {}
            test_info = {}
          end
        end

        test_capture_flag = test_text
      end
      if pkg_capture_flag == "target_file" and pkg[pkg_text] == nil then
        pkg[pkg_text] = pkg_info
      end

      pkg_capture_flag = pkg_text
    end

    if unit_capture_flag == "source_file" then
      filename = unit_text
      source_files[filename] = pkg
      pkg = {}
    end

    unit_capture_flag = unit_text
  end
  M.tests = vim.deepcopy(source_files)

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

  for filename, files in pairs(M.tests) do
    for p, tst_pkg in pairs(files) do
      if p == pkg then
        return tst_pkg, filename
      end
    end
  end

  return nil
end

function M.get_tests_by_name(pkg, name)
  if next(M.tests) == nil then
    M.get_tests()
  end

  local tst_pkg, filename = get_pkg_tests(pkg)
  if tst_pkg == nil then
    return nil
  end

  for _, test in pairs(tst_pkg) do
    if test.name == name then
      test.filename = filename
      test.pkg = pkg
      return test
    end
  end

  return nil
end

return M
