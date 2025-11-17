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
  local pkg_info = {}
  local pkg = ""
  local pkg_capture_flag = ""
  local pkg_match = "test_unit"
  local pkg_query = M.query_element(pkg_match)
  -----------------
  -- **SOURCES** --
  -----------------
  local src_capture_flag = ""
  local src_info = {}
  local src_match = "tested"
  local src_query = M.query_element(src_match)

  for _, unit_node in query:iter_captures(root, buf_id) do
    local unit_text =
      vim.treesitter.get_node_text(unit_node, buf_id):gsub('"', "")
    for id, pkg_node in pkg_query:iter_captures(unit_node, buf_id) do
      local pkg_text =
        vim.treesitter.get_node_text(pkg_node, buf_id):gsub('"', "")
      print(pkg_text)
      print(pkg_query.captures[id])
      for _, src_node in src_query:iter_captures(pkg_node, buf_id) do
        local src_text =
          vim.treesitter.get_node_text(src_node, buf_id):gsub('"', "")
        -- print(src_text)
        if src_capture_flag == "name" then
          src_info.name = src_text
        elseif src_capture_flag == "line" then
          src_info.line = src_text
        elseif src_capture_flag == "column" then
          src_info.column = src_text
          table.insert(pkg_info, src_info)
          src_info = {}
        end

        pkg_capture_flag = src_text
      end
      --       M.tests = vim.deepcopy(source_files)
      if pkg_capture_flag == "target_file" then
        pkg = pkg_text
        pkg_info = { [pkg] = {} }
      end

      pkg_capture_flag = pkg_text
      -- end
    end

    if unit_capture_flag == "source_file" then
      filename = unit_text
      source_files[filename] = pkg_info
      pkg_info = {}
      print(vim.inspect(source_files))
    end

    unit_capture_flag = unit_text
  end

  -- local subpr_src = {}
  -- local capture_flag = ""
  --
  -- local pkg_capture_flag = ""
  -- local query = M.query_pkg(unit_match)
  -- for _, node in query:iter_captures(root, buf_id) do
  --   local text = vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
  --   if pkg_capture_flag == "unit" then
  --     filename = text
  --   elseif
  --     pkg_capture_flag == "test_unit" and source_files[filename] == nil
  --   then
  --     pkg = text
  --     source_files[filename] = { [pkg] = {} }
  --   end
  --
  --   pkg_capture_flag = text
  -- end
  --
  -- local subpr_src = {}
  -- local capture_flag = ""
  --
  -- -----------------
  -- -- **SOURCES** --
  -- -----------------
  -- for name, file_info in pairs(source_files) do
  --   for p, _ in pairs(file_info) do
  --     query = M.query_subpr_by_pkg(p)
  --     for _, node in query:iter_captures(root, buf_id) do
  --       local text = vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
  --       if capture_flag == "name" then
  --         subpr_src.name = text
  --       elseif capture_flag == "line" then
  --         subpr_src.line = text
  --       elseif capture_flag == "column" then
  --         subpr_src.column = text
  --         table.insert(source_files[name][p], subpr_src)
  --         subpr_src = {}
  --       end
  --
  --       capture_flag = text
  --     end
  --     M.tests = vim.deepcopy(source_files)
  --   end
  -- end
  --
  -- ---------------
  -- -- **TESTS** --
  -- ---------------
  -- local tst = {}
  -- capture_flag = ""
  --
  -- for filename, file_info in pairs(M.tests) do
  --   for pkg, pkg_info in pairs(file_info) do
  --     for _, src in pairs(pkg_info) do
  --       query = M.query_test_info_by_subpr(src.name)
  --       print("TTT: " .. src.name)
  --       print(vim.inspect(src))
  --       for _, node in query:iter_captures(root, buf_id) do
  --         local text = vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
  --         -- print(text)
  --         if capture_flag == "file" then
  --           tst.file = text
  --         elseif capture_flag == "line" then
  --           tst.line = text
  --         elseif capture_flag == "column" then
  --           tst.column = text
  --         elseif capture_flag == "name" then
  --           tst.name = text
  --           -- M.tests[filename][pkg] = tst
  --           src.test = tst
  --           -- print(vim.inspect(M.tests[filename][pkg]))
  --           -- tst = {}
  --         end
  --
  --         capture_flag = text
  --       end
  --     end
  --   end
  -- end

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
