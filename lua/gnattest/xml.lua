local M = {}

local xml_info = {}

local function query_element(match)
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

local function query_test_info()
  local query_string = '\
                    (element\
                        (STag (Name) @tag\
                            (#eq? @tag "tested")\
                            (Attribute (Name) @string\
                                (AttValue) @src)\
                        )\
                        (content\
                            (element\
                                (STag (Name) @t_tag\
                                  (#eq? @t_tag "test_case")\
                                  (Attribute (Name) @t_string\
                                    (AttValue) @t_src)\
                                )\
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

local function create_xml_buf()
  local xml_file = vim.fs.find(function(name)
    return name == "gnattest.xml"
  end)[1]
  if not xml_file then
    require("gnattest.utils").notify(
      "Please, generate tests with `:Gnattest generate` command first",
      vim.log.levels.ERROR
    )
    return nil
  end
  local xml_lines = vim.fn.readfile(xml_file)

  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, xml_lines)

  return buf_id
end

local function query_tag_elements(tag, empty)
  local tag_node = empty and "EmptyElemTag" or "STag"
  local query_string = string.format(
    [[
      (element
        (%s
          (Name) @tag
          (#eq? @tag "%s")
        )
      ) @element
    ]],
    tag_node,
    tag
  )

  return vim.treesitter.query.parse("xml", query_string)
end

local function query_attributes()
  local query_string = [[
    (Attribute
      (Name) @name
      (AttValue) @value
    )
  ]]

  return vim.treesitter.query.parse("xml", query_string)
end

local function capture_ids(query)
  local ids = {}

  for id, name in ipairs(query.captures or {}) do
    ids[name] = id
  end

  return ids
end

local function first_capture_node(match, id)
  if not id then
    return nil
  end

  local nodes = match[id]
  if nodes == nil then
    return nil
  end

  return nodes[1]
end

local function get_node_text(node, buf_id)
  if node == nil then
    return nil
  end

  return vim.treesitter.get_node_text(node, buf_id):gsub('"', "")
end

local function get_attributes(node, buf_id, attr_query, attr_ids)
  local attrs = {}

  for _, attr_match in attr_query:iter_matches(node, buf_id) do
    local name =
      get_node_text(first_capture_node(attr_match, attr_ids.name), buf_id)
    local value =
      get_node_text(first_capture_node(attr_match, attr_ids.value), buf_id)

    if name ~= nil and value ~= nil then
      attrs[name] = value
    end
  end

  return attrs
end

local function get_start_tag_node(element_node, empty)
  local tag_type = empty and "EmptyElemTag" or "STag"

  for child in element_node:iter_children() do
    if child:type() == tag_type then
      return child
    end
  end

  return nil
end

local function parse_xml_info_with_matches(root, buf_id)
  local source_files = {}

  local unit_query = query_tag_elements("unit")
  local pkg_query = query_tag_elements("test_unit")
  local tested_query = query_tag_elements("tested")
  local case_query = query_tag_elements("test_case")
  local test_query = query_tag_elements("test", true)
  local attr_query = query_attributes()

  local unit_ids = capture_ids(unit_query)
  local pkg_ids = capture_ids(pkg_query)
  local tested_ids = capture_ids(tested_query)
  local case_ids = capture_ids(case_query)
  local test_ids = capture_ids(test_query)
  local attr_ids = capture_ids(attr_query)

  for _, unit_match in unit_query:iter_matches(root, buf_id) do
    local unit_node = first_capture_node(unit_match, unit_ids.element)
    local unit_tag = get_start_tag_node(unit_node)
    local unit_attrs = unit_tag
        and get_attributes(unit_tag, buf_id, attr_query, attr_ids)
      or {}
    local source_file = unit_attrs.source_file

    if source_file ~= nil then
      local packages = source_files[source_file]
      if packages == nil then
        packages = {}
        source_files[source_file] = packages
      end

      for _, pkg_match in pkg_query:iter_matches(unit_node, buf_id) do
        local pkg_node = first_capture_node(pkg_match, pkg_ids.element)
        local pkg_tag = get_start_tag_node(pkg_node)
        local pkg_attrs = pkg_tag
            and get_attributes(pkg_tag, buf_id, attr_query, attr_ids)
          or {}
        local pkg_name = pkg_attrs.target_file

        if pkg_name ~= nil then
          local pkg_info = packages[pkg_name]
          if pkg_info == nil then
            pkg_info = {}
            packages[pkg_name] = pkg_info
          end

          for _, tested_match in tested_query:iter_matches(pkg_node, buf_id) do
            local tested_node =
              first_capture_node(tested_match, tested_ids.element)
            local tested_tag = get_start_tag_node(tested_node)
            local source_attrs = tested_tag
                and get_attributes(tested_tag, buf_id, attr_query, attr_ids)
              or {}

            local source_info = {
              name = source_attrs.name,
              line = source_attrs.line,
              column = source_attrs.column,
              case = {},
            }
            local tests = {}

            for _, case_match in case_query:iter_matches(tested_node, buf_id) do
              local case_node = first_capture_node(case_match, case_ids.element)
              local case_tag = get_start_tag_node(case_node)
              local case_attrs = case_tag
                  and get_attributes(case_tag, buf_id, attr_query, attr_ids)
                or {}
              local case_info = {
                name = case_attrs.name,
                line = case_attrs.line,
                column = case_attrs.column,
              }

              for _, test_match in test_query:iter_matches(case_node, buf_id) do
                local test_node =
                  first_capture_node(test_match, test_ids.element)
                local test_tag = get_start_tag_node(test_node, true)
                local test_attrs = test_tag
                    and get_attributes(test_tag, buf_id, attr_query, attr_ids)
                  or {}

                table.insert(source_info.case, {
                  name = case_info.name,
                  line = case_info.line,
                  column = case_info.column,
                })
                table.insert(tests, {
                  name = test_attrs.name,
                  file = test_attrs.file,
                  line = test_attrs.line,
                  column = test_attrs.column,
                })
              end
            end

            if next(tests) ~= nil then
              table.insert(pkg_info, {
                source = source_info,
                tests = tests,
              })
            end
          end
        end
      end
    end
  end

  return source_files
end

local function parse_xml_info_legacy(root, buf_id)
  local source_files = {}

  --------------
  -- **UNIT** --
  --------------
  local filename
  local unit_capture_flag = ""
  local unit_match = "unit"
  local query = query_element(unit_match)
  ------------------
  -- **PACKAGE** --
  ------------------
  local pkg = {}
  local pkg_info = {}
  local pkg_capture_flag = ""
  local pkg_match = "test_unit"
  local pkg_query = query_element(pkg_match)
  -----------------
  -- **SOURCES** --
  -----------------
  local test_capture_flag = ""
  local gnattest_info = {}
  local src_info = {}
  local test_cases = {}
  local case = {}
  local tests = {}
  local test_info = {}
  local test_query = query_test_info()

  for _, unit_node in query:iter_captures(root, buf_id) do
    local unit_text =
      vim.treesitter.get_node_text(unit_node, buf_id):gsub('"', "")
    for _, pkg_node in pkg_query:iter_captures(unit_node, buf_id) do
      local pkg_text =
        vim.treesitter.get_node_text(pkg_node, buf_id):gsub('"', "")
      for id, test_node in test_query:iter_captures(pkg_node, buf_id) do
        local test_text =
          vim.treesitter.get_node_text(test_node, buf_id):gsub('"', "")
        local capture_id = test_query.captures[id]
        if capture_id == "tag" then
          if next(gnattest_info) ~= nil then
            table.insert(pkg_info, gnattest_info)
            gnattest_info.tests = tests
          end
          src_info = {}
          gnattest_info = {}
          test_cases = {}
          tests = {}
        elseif capture_id == "src" then
          if test_capture_flag == "name" then
            src_info.name = test_text
          elseif test_capture_flag == "column" then
            src_info.column = test_text
          elseif test_capture_flag == "line" then
            src_info.line = test_text
          end
        elseif capture_id == "t_src" then
          if test_capture_flag == "name" then
            case.name = test_text
          elseif test_capture_flag == "line" then
            case.line = test_text
          elseif test_capture_flag == "column" then
            case.column = test_text
            table.insert(test_cases, case)
            case = {}
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
            gnattest_info.source = src_info
            gnattest_info.source.case = test_cases
            table.insert(tests, test_info)
            test_info = {}
          end
        end

        test_capture_flag = test_text
      end
      if pkg_capture_flag == "target_file" and pkg[pkg_text] == nil then
        if next(gnattest_info) ~= nil then
          table.insert(pkg_info, gnattest_info)
          gnattest_info.tests = tests
        end
        pkg[pkg_text] = pkg_info
        pkg_info = {}
        gnattest_info = {}
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

  return source_files
end

function M.get_xml_info(refresh)
  if next(xml_info) ~= nil and refresh ~= true then
    return xml_info
  end

  local buf_id = create_xml_buf()
  if buf_id == nil then
    return nil
  end

  local root = vim.treesitter.get_parser(buf_id, "xml"):parse()[1]:root()

  local source_files
  local tested_query = query_test_info()

  if tested_query.iter_matches then
    source_files = parse_xml_info_with_matches(root, buf_id)
  else
    source_files = parse_xml_info_legacy(root, buf_id)
  end

  xml_info = vim.deepcopy(source_files)

  return xml_info
end

function M.get_pkg_tests(pkg)
  if next(xml_info) == nil then
    M.get_xml_info()
  end

  for filename, files in pairs(xml_info) do
    for p, pkg_info in pairs(files) do
      if p == pkg then
        return pkg_info, filename
      end
    end
  end

  return nil
end

function M.get_test_from_src_case_line(filename, line)
  if next(xml_info) == nil then
    M.get_xml_info()
  end

  for f, files in pairs(xml_info) do
    for p, pkg_info in pairs(files) do
      for _, test_info in pairs(pkg_info) do
        for c, case in ipairs(test_info.source.case) do
          if f == filename and tonumber(case.line) == line then
            local info = vim.deepcopy(test_info)
            info.source.case = case
            info.tests = test_info.tests[c]
            return f, p, info
          end
        end
      end
    end
  end

  return nil
end

function M.get_test_by_name(pkg, name)
  if next(xml_info) == nil then
    M.get_xml_info()
  end

  local pkg_info, filename = M.get_pkg_tests(pkg)
  if pkg_info == nil then
    return nil
  end

  for _, test_info in pairs(pkg_info) do
    if test_info.source.name == name then
      return test_info, filename
    end
  end

  return nil
end

function M.get_gnattest_info_on_line(lnum)
  if next(xml_info) == nil then
    M.get_xml_info()
  end

  local utils = require("gnattest.utils")
  local als = require("gnattest.ada_ls")

  local subr_name, range = als.get_subprogram_name_from_line(lnum)
  local start_line = 0
  local end_line = 0

  if subr_name == nil then
    return nil
  end

  if range and range.start and range.start.line then
    start_line = range.start.line
  end
  if range and range.end_ and range.end_.line then
    end_line = range.end_.line
  end

  local filename = utils.split_filename(utils.get_filename())

  for f, file_info in pairs(xml_info) do
    for p, pkg_info in pairs(file_info) do
      for _, info in pairs(pkg_info) do
        if
          not utils.is_gnattest_file()
          and vim.fn.match(f, filename) == 0
          and vim.fn.match(info.source.name, subr_name) ~= -1
        then
          return f, p, info
        elseif utils.is_gnattest_file() then
          for _, test in ipairs(info.tests) do
            if
              vim.fn.match(test.file, filename) == 0
              and start_line <= tonumber(test.line)
              and end_line >= tonumber(test.line)
            then
              return f, p, info
            end
          end
        end
      end
    end
  end
  return nil
end

function M.get_gnattest_info_on_cursor()
  return M.get_gnattest_info_on_line(vim.fn.getpos(".")[2])
end

-- Test-specific exports - only exposed in test mode
if os.getenv("GNATTEST_TEST_MODE") then
  M._query_element = query_element
  M._query_test_info = query_test_info
  M._create_xml_buf = create_xml_buf
  M._xml_info = xml_info
end

return M
