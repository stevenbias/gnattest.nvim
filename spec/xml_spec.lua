local xml = require("gnattest.xml")

-- Stubs for Neovim API used in xml.lua
local stub_vim_api = function()
  _G.vim = _G.vim or {}
  _G.vim.treesitter = {
    query = {
      parse = function()
        return {
          captures = { "src", "tst" },
          iter_captures = function()
            local n = 0
            return function()
              n = n + 1
              if n == 1 then
                return 1, "node1"
              elseif n == 2 then
                return 2, "node2"
              end
            end
          end,
        }
      end,
    },
    get_parser = function()
      return {
        parse = function()
          return {
            {
              root = function()
                return "root"
              end,
            },
          }
        end,
      }
    end,
    get_node_text = function(node)
      return tostring(node)
    end,
  }
  _G.vim.fs = {
    find = function()
      return { "mock_gnattest.xml" }
    end,
  }
  _G.vim.fn = {
    readfile = function()
      return {
        "<xml><unit>source_file</unit><test_unit>target_file</test_unit></xml>",
      }
    end,
  }
  _G.vim.api = {
    nvim_create_buf = function()
      return 1
    end,
    nvim_buf_set_lines = function() end,
    nvim__get_runtime = function()
      return {}
    end,
  }
  _G.vim.inspect = function(obj)
    return tostring(obj)
  end
end

-- Simplified XML parsing mock setup
local function setup_xml_parsing_mocks(
  unit_captures,
  pkg_captures,
  test_captures,
  node_text_mapping
)
  _G.vim.treesitter.query.parse = function(_, query_str)
    return {
      captures = query_str:find("test_unit") and { "target_file" }
        or query_str:find("unit") and { "source_file" }
        or { "src", "tst" },
      iter_captures = function()
        local captures = query_str:find("test_unit") and (pkg_captures or {})
          or query_str:find("unit") and (unit_captures or {})
          or (test_captures or {})
        local idx = 0
        return function()
          idx = idx + 1
          if idx <= #captures then
            return captures[idx].id, captures[idx].node
          end
        end
      end,
    }
  end
  _G.vim.treesitter.get_node_text = function(node)
    return (node_text_mapping and node_text_mapping[node]) or tostring(node)
  end
  _G.vim.fn.readfile = function()
    return { "<tests_mapping></tests_mapping>" }
  end
end

describe("gnattest.xml", function()
  before_each(function()
    stub_vim_api()
    package.loaded["gnattest.xml"] = nil
    xml = require("gnattest.xml")
  end)

  after_each(function()
    package.loaded["gnattest.xml"] = nil
    package.preload["gnattest.xml"] = nil
  end)

  describe("module structure", function()
    it("exports required functions", function()
      assert.is_function(xml.get_test_by_name)
      assert.is_function(xml.get_xml_info)
      assert.is_function(xml.get_pkg_tests)
      assert.is_function(xml.get_test_from_src_file_line)
      assert.is_function(xml.get_gnattest_info_on_line)
      assert.is_function(xml.get_gnattest_info_on_cursor)
    end)
  end)

  describe("get_tests with real XML parsing", function()
    it("parses complete XML structure correctly", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      _G.vim.fs.find = function()
        return { fixture_path }
      end

      _G.vim.fn.readfile = function()
        return xml_lines
      end

      _G.vim.treesitter.get_parser = function()
        return {
          parse = function()
            return {
              {
                root = function()
                  return "root"
                end,
              },
            }
          end,
        }
      end

      local result = xml.get_xml_info()
      assert.is_table(result)
      assert.is_not_nil(result)
    end)

    it("get_tests initializes empty xml_info table", function()
      _G.vim.fs.find = function()
        return { "spec/fixtures/gnattest.xml" }
      end

      _G.vim.fn.readfile = function()
        return { "<gnattest></gnattest>" }
      end

      local result = xml.get_xml_info()
      assert.is_table(result)
    end)

    it("refresh bypasses cache", function()
      local parse_calls = 0
      _G.vim.treesitter.get_parser = function()
        parse_calls = parse_calls + 1
        return {
          parse = function()
            return {
              {
                root = function()
                  return "root"
                end,
              },
            }
          end,
        }
      end

      setup_xml_parsing_mocks(
        { { id = 1, node = "unit_flag" }, { id = 1, node = "unit_file" } },
        {},
        {},
        { unit_flag = "source_file", unit_file = "my_file.ads" }
      )

      xml.get_xml_info()
      xml.get_xml_info()
      xml.get_xml_info(true)

      assert.equals(2, parse_calls)
    end)
  end)

  describe("real fixture parsing", function()
    local fixture_path = "spec/fixtures/gnattest.xml"
    local xml_lines

    before_each(function()
      xml_lines = {}
      local file = io.open(fixture_path, "r")
      assert.is_not_nil(file)
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end
    end)

    it("validates fixture file XML structure and content", function()
      assert.is_true(#xml_lines > 0)
      local content = table.concat(xml_lines, "\n")

      assert.is_not_nil(string.find(content, "package_a%.ads"))
      assert.is_not_nil(string.find(content, "package_b%.ads"))
      assert.is_not_nil(string.find(content, "package_c%.ads"))

      local test_unit_count = 0
      for _ in string.gmatch(content, "<test_unit") do
        test_unit_count = test_unit_count + 1
      end
      assert.is_true(test_unit_count > 1)

      local tested_count = 0
      for _ in string.gmatch(content, "<tested") do
        tested_count = tested_count + 1
      end
      assert.is_true(tested_count > 1)

      local test_case_count = 0
      for _ in string.gmatch(content, "<test_case") do
        test_case_count = test_case_count + 1
      end
      assert.is_true(test_case_count > 1)

      assert.is_true(string.find(content, "<tests_mapping") ~= nil)
      assert.is_true(string.find(content, "<unit") ~= nil)
      assert.is_true(string.find(content, "<test_unit") ~= nil)
      assert.is_true(string.find(content, "<tested") ~= nil)
      assert.is_true(string.find(content, "<test_case") ~= nil)
      assert.is_true(string.find(content, "<test") ~= nil)
    end)
  end)

  describe("field assignment coverage", function()
    it("exercises all XML field assignment branches", function()
      _G.vim.fs.find = function()
        return { "gnattest.xml" }
      end
      _G.vim.fn.readfile = function()
        return { "<tests></tests>" }
      end

      _G.vim.treesitter.query.parse = function(_, query_str)
        if query_str:find("test_unit") then
          return {
            captures = { "pkg" },
            iter_captures = function()
              local called = false
              return function()
                if not called then
                  called = true
                  return 1, "pkg_node"
                end
              end
            end,
          }
        else
          return {
            captures = { "src", "tst" },
            iter_captures = function()
              local i = 0
              local seq = {
                { 3, "flag_name" },
                { 1, "src_name" },
                { 3, "flag_line" },
                { 1, "src_line" },
                { 3, "flag_column" },
                { 1, "src_column" },
                { 3, "flag_file" },
                { 2, "tst_file" },
                { 3, "flag_line2" },
                { 2, "tst_line" },
                { 3, "flag_column2" },
                { 2, "tst_column" },
                { 3, "flag_name2" },
                { 2, "tst_name" },
              }
              return function()
                i = i + 1
                return i <= #seq and seq[i][1] or nil,
                  i <= #seq and seq[i][2] or nil
              end
            end,
          }
        end
      end

      _G.vim.treesitter.get_node_text = function(node)
        local map = {
          pkg_node = "Pkg",
          flag_name = "name",
          flag_line = "line",
          flag_column = "column",
          flag_file = "file",
          flag_line2 = "line",
          flag_column2 = "column",
          flag_name2 = "name",
          src_name = "Fn",
          src_line = "42",
          src_column = "10",
          tst_file = "test.adb",
          tst_line = "15",
          tst_column = "5",
          tst_name = "Test_Fn",
        }
        return map[node] or "default"
      end

      assert.is_table(xml.get_xml_info())
    end)
  end)

  describe("XML parsing logic coverage tests", function()
    describe("core data structure population", function()
      it("populates source_files table from unit captures", function()
        setup_xml_parsing_mocks({
          { id = 1, node = "src_node_1" },
          { id = 1, node = "src_node_2" },
        }, { { id = 1, node = "pkg_node" } }, {}, {
          src_node_1 = "source_file",
          src_node_2 = "my_file.ads",
          pkg_node = "target_file",
        })

        local result = xml.get_xml_info()
        assert.is_table(result)
        assert.is_not_nil(result["my_file.ads"])
      end)

      it("stores package info from package captures", function()
        setup_xml_parsing_mocks({
          { id = 1, node = "src_node_1" },
          { id = 1, node = "src_node_2" },
        }, {
          { id = 1, node = "target_node_1" },
          { id = 1, node = "target_node_2" },
        }, {}, {
          src_node_1 = "source_file",
          src_node_2 = "file.ads",
          target_node_1 = "target_file",
          target_node_2 = "Package_Under_Test",
        })

        local result = xml.get_xml_info()
        assert.is_not_nil(result["file.ads"])
        assert.is_not_nil(result["file.ads"]["Package_Under_Test"])
      end)

      it("handles multiple source files correctly", function()
        setup_xml_parsing_mocks({
          { id = 1, node = "sf_node" },
          { id = 1, node = "filename_node" },
          { id = 1, node = "sf_node2" },
          { id = 1, node = "filename_node2" },
        }, {}, {}, {
          sf_node = "source_file",
          filename_node = "package_a.ads",
          sf_node2 = "source_file",
          filename_node2 = "package_b.ads",
        })

        local result = xml.get_xml_info()
        assert.is_not_nil(result["package_a.ads"])
        assert.is_not_nil(result["package_b.ads"])
      end)
    end)

    describe("comprehensive parsing verification", function()
      it(
        "verifies xml.get_xml_info() returns table with various parsing scenarios",
        function()
          setup_xml_parsing_mocks({}, {}, {}, {})
          assert.is_table(xml.get_xml_info())
        end
      )
    end)
  end)

  if os.getenv("GNATTEST_TEST_MODE") then
    -- Helper to inject test data into xml module (requires GNATTEST_TEST_MODE=1)
    -- This helper needs access to _xml_info which is only exported in test mode
    local function inject_xml_data(data)
      package.loaded["gnattest.xml"] = nil
      local xml_mod = require("gnattest.xml")

      for k, v in pairs(data) do
        xml_mod._xml_info[k] = v
      end

      return xml_mod
    end

    describe("get_tests_by_name", function()
      it("returns test by name if present", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = { { source = { name = "testA" }, test = {} } },
          },
        })
        local result, filename = xml.get_test_by_name("pkg1", "testA")
        assert.is_table(result)
        assert.equals("testA", result.source.name)
        assert.equals("file1", filename)
      end)

      it("returns nil when package or name missing", function()
        local cases = {
          { pkg = "pkg1", name = "missing" },
          { pkg = "missing_pkg", name = "testA" },
        }

        for _, case in ipairs(cases) do
          xml = inject_xml_data({
            file1 = { pkg1 = { { source = { name = "testA" }, test = {} } } },
          })
          assert.is_nil(xml.get_test_by_name(case.pkg, case.name))
        end
      end)

      it("handles multiple tests and packages", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              { source = { name = "testA" }, test = {} },
              { source = { name = "testB" }, test = {} },
            },
            pkg2 = { { source = { name = "testC" }, test = {} } },
          },
        })
        local testA = xml.get_test_by_name("pkg1", "testA")
        local testB = xml.get_test_by_name("pkg1", "testB")
        local testC, filename = xml.get_test_by_name("pkg2", "testC")
        assert.equals("testA", testA.source.name)
        assert.equals("testB", testB.source.name)
        assert.equals("testC", testC.source.name)
        assert.equals("file1", filename)
      end)

      it("retrieves test with complete metadata", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              {
                source = { name = "test1", line = "10", column = "2" },
                test = { name = "test_test1", file = "test.ads" },
              },
            },
          },
        })
        local result, filename = xml.get_test_by_name("pkg1", "test1")
        assert.equals("test1", result.source.name)
        assert.equals("test.ads", result.test.file)
        assert.equals("10", result.source.line)
        assert.equals("2", result.source.column)
        assert.equals("file1", filename)
      end)

      it("returns first match when duplicates exist", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              { source = { name = "test1" }, test = {} },
              { source = { name = "test1" }, test = {} },
            },
          },
        })
        local result = xml.get_test_by_name("pkg1", "test1")
        assert.is_not_nil(result)
        assert.equals("test1", result.source.name)
      end)
    end)

    describe("get_pkg_tests", function()
      it("returns tests for matching package", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = { { source = { name = "testA" }, test = {} } },
          },
        })

        local tests, filename = xml.get_pkg_tests("pkg1")

        assert.equals("file1", filename)
        assert.equals("testA", tests[1].source.name)
      end)

      it("returns nil for missing package", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = { { source = { name = "testA" }, test = {} } },
          },
        })

        assert.is_nil(xml.get_pkg_tests("missing_pkg"))
      end)
    end)

    describe("get_test_from_src_file_line", function()
      it("finds test by filename and line", function()
        xml = inject_xml_data({
          ["my_package.ads"] = {
            Package1 = {
              {
                source = { name = "My_Function", line = "10", column = "2" },
                test = { name = "Test_My_Function", file = "test.adb" },
              },
            },
          },
        })

        local file, pkg, info =
          xml.get_test_from_src_file_line("my_package.ads", 10)

        assert.equals("my_package.ads", file)
        assert.equals("Package1", pkg)
        assert.equals("My_Function", info.source.name)
      end)

      it("populates xml_info when empty", function()
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end

        local parse_calls = 0
        _G.vim.treesitter.get_parser = function()
          parse_calls = parse_calls + 1
          return {
            parse = function()
              return {
                {
                  root = function()
                    return "root"
                  end,
                },
              }
            end,
          }
        end

        setup_xml_parsing_mocks(
          { { id = 1, node = "unit_flag" }, { id = 1, node = "unit_file" } },
          {},
          {},
          { unit_flag = "source_file", unit_file = "my_file.ads" }
        )

        assert.is_nil(xml.get_test_from_src_file_line("my_package.ads", 10))
        assert.equals(1, parse_calls)
      end)

      it("returns nil when no match", function()
        xml = inject_xml_data({
          ["my_package.ads"] = {
            Package1 = {
              {
                source = { name = "My_Function", line = "10", column = "2" },
                test = { name = "Test_My_Function", file = "test.adb" },
              },
            },
          },
        })

        assert.is_nil(xml.get_test_from_src_file_line("my_package.ads", 11))
      end)
    end)

    describe("get_gnattest_info_on_line", function()
      local original_get_subprogram
      local original_is_gnattest_file
      local original_get_filename
      local original_match

      before_each(function()
        original_get_subprogram =
          require("gnattest.ada_ls").get_subprogram_name_from_line
        require("gnattest.ada_ls").get_subprogram_name_from_line = function()
          return "My_Function"
        end

        local utils = require("gnattest.utils")
        original_is_gnattest_file = utils.is_gnattest_file
        original_get_filename = utils.get_filename
        utils.is_gnattest_file = function()
          return false
        end
        utils.get_filename = function()
          return "my_package.ads"
        end

        original_match = _G.vim.fn.match
        _G.vim.fn.match = function(str, pattern)
          if type(str) == "string" and type(pattern) == "string" then
            return str:find(pattern, 1, true) and 0 or -1
          end
          return -1
        end
      end)

      after_each(function()
        require("gnattest.ada_ls").get_subprogram_name_from_line =
          original_get_subprogram
        local utils = require("gnattest.utils")
        utils.is_gnattest_file = original_is_gnattest_file
        utils.get_filename = original_get_filename
        _G.vim.fn.match = original_match
      end)

      it("returns nil when subprogram name missing", function()
        require("gnattest.ada_ls").get_subprogram_name_from_line = function()
          return nil
        end

        assert.is_nil(xml.get_gnattest_info_on_line(3))
      end)

      it("returns info when in source file", function()
        xml = inject_xml_data({
          ["my_package.ads"] = {
            Package1 = {
              {
                source = { name = "My_Function", line = "10", column = "2" },
                test = {
                  name = "Test_My_Function",
                  file = "test.adb",
                  line = "20",
                  column = "4",
                },
              },
            },
          },
        })

        local file, pkg, info = xml.get_gnattest_info_on_line(10)

        assert.equals("my_package.ads", file)
        assert.equals("Package1", pkg)
        assert.equals("My_Function", info.source.name)
      end)

      it("returns info when in gnattest file", function()
        local utils = require("gnattest.utils")
        utils.is_gnattest_file = function()
          return true
        end
        utils.get_filename = function()
          return "test_file.adb"
        end

        xml = inject_xml_data({
          ["my_package.ads"] = {
            Package1 = {
              {
                source = { name = "My_Function", line = "10", column = "2" },
                test = {
                  name = "Test_My_Function",
                  file = "test_file.adb",
                  line = "20",
                  column = "4",
                },
              },
            },
          },
        })

        local file, pkg, info = xml.get_gnattest_info_on_line(20)

        assert.equals("my_package.ads", file)
        assert.equals("Package1", pkg)
        assert.equals("Test_My_Function", info.test.name)
      end)

      it("returns nil when no matches", function()
        xml = inject_xml_data({
          ["my_package.ads"] = {
            Package1 = {
              {
                source = { name = "Other_Function", line = "10", column = "2" },
                test = {
                  name = "Test_Other_Function",
                  file = "test_file.adb",
                  line = "20",
                  column = "4",
                },
              },
            },
          },
        })

        assert.is_nil(xml.get_gnattest_info_on_line(99))
      end)
    end)

    describe("get_gnattest_info_on_cursor", function()
      it("delegates to get_gnattest_info_on_line", function()
        local original_getpos = _G.vim.fn.getpos
        _G.vim.fn.getpos = function()
          return { 0, 10, 0 }
        end
        local get_line_calls = {}
        local original_get_line = xml.get_gnattest_info_on_line
        xml.get_gnattest_info_on_line = function(lnum)
          table.insert(get_line_calls, lnum)
          return nil
        end

        xml.get_gnattest_info_on_cursor()

        assert.equals(1, #get_line_calls)
        assert.equals(10, get_line_calls[1])

        xml.get_gnattest_info_on_line = original_get_line
        _G.vim.fn.getpos = original_getpos
      end)
    end)

    describe("edge cases", function()
      it("handles empty tests and enforces case sensitivity", function()
        xml = inject_xml_data({})
        assert.is_nil(xml.get_test_by_name("pkg", "test"))

        xml = inject_xml_data({
          file1 = { pkg1 = { { source = { name = "TestCase" }, test = {} } } },
        })
        assert.is_not_nil(xml.get_test_by_name("pkg1", "TestCase"))
        assert.is_nil(xml.get_test_by_name("pkg1", "testcase"))
      end)

      it("handles special characters in names", function()
        xml = inject_xml_data({
          file1 = {
            ["pkg.sub"] = { { source = { name = "test_1" }, test = {} } },
          },
        })
        local result = xml.get_test_by_name("pkg.sub", "test_1")
        assert.equals("test_1", result.source.name)
      end)

      it("handles nested package names with underscores", function()
        xml = inject_xml_data({
          file1 = {
            ["my_pkg_v1"] = { { source = { name = "my_test" }, test = {} } },
          },
        })
        local result = xml.get_test_by_name("my_pkg_v1", "my_test")
        assert.equals("my_test", result.source.name)
      end)

      it("handles numeric line and column values", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              {
                source = { name = "test", line = "100", column = "20" },
                test = {},
              },
            },
          },
        })
        local result = xml.get_test_by_name("pkg1", "test")
        assert.equals("100", result.source.line)
        assert.equals("20", result.source.column)
      end)
    end)

    local function set_xml_info(data)
      for k in pairs(xml._xml_info) do
        xml._xml_info[k] = nil
      end
      for k, v in pairs(data) do
        xml._xml_info[k] = v
      end
    end

    describe("xml_info internal state tests", function()
      it("get_xml_info returns cached results on second call", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["gnattest_prefix_my_package.ads"] = {
              { name = "test_add", line = 50 },
            },
          },
        })
        local result1 = xml.get_xml_info()
        local result2 = xml.get_xml_info()
        assert.equals(result1, result2)
      end)

      it("get_xml_info refreshes when requested", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["gnattest_prefix_my_package.ads"] = {
              { name = "test_add", line = 50 },
            },
          },
        })

        local parse_calls = 0
        _G.vim.treesitter.get_parser = function()
          parse_calls = parse_calls + 1
          return {
            parse = function()
              return {
                {
                  root = function()
                    return "root"
                  end,
                },
              }
            end,
          }
        end

        setup_xml_parsing_mocks(
          { { id = 1, node = "unit_flag" }, { id = 1, node = "unit_file" } },
          {},
          {},
          { unit_flag = "source_file", unit_file = "my_file.ads" }
        )

        xml.get_xml_info(true)

        assert.equals(1, parse_calls)
      end)

      it("structure contains source files and test packages", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["test_pkg"] = { { source = { name = "test1" }, test = {} } },
            ["gnattest_prefix_my_package.ads"] = {
              { source = { name = "test2" }, test = {} },
            },
          },
        })
        local result = xml.get_xml_info()
        assert.is_not_nil(result["src/my_package.ads"])
        assert.equals(
          "test2",
          result["src/my_package.ads"]["gnattest_prefix_my_package.ads"][1].source.name
        )
      end)

      it("handles multiple source files", function()
        set_xml_info({
          ["src/package1.ads"] = {
            ["test_pkg1"] = { { source = { name = "test1" }, test = {} } },
          },
          ["src/package2.ads"] = {
            ["test_pkg2"] = { { source = { name = "test2" }, test = {} } },
          },
        })
        local result = xml.get_xml_info()
        assert.is_not_nil(result["src/package1.ads"])
        assert.is_not_nil(result["src/package2.ads"])
        local count = 0
        for _ in pairs(result) do
          count = count + 1
        end
        assert.equals(2, count)
      end)
    end)

    describe("xml_info structure validation", function()
      it("src_info contains name, line, column, and test fields", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["test_pkg"] = {
              {
                source = {
                  name = "add_numbers",
                  line = "10",
                  column = "5",
                },
                test = {
                  name = "test_add_positive",
                  file = "test.ads",
                  line = "50",
                  column = "3",
                },
              },
            },
          },
        })
        local src =
          xml.get_xml_info()["src/my_package.ads"]["test_pkg"][1].source
        assert.equals("add_numbers", src.name)
        assert.equals("10", src.line)
        assert.equals("5", src.column)
      end)

      it("test_info contains name, file, line, and column fields", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["test_pkg"] = {
              {
                source = { name = "proc" },
                test = {
                  name = "test_proc",
                  file = "test.ads",
                  line = "100",
                  column = "3",
                },
              },
            },
          },
        })
        local test =
          xml.get_xml_info()["src/my_package.ads"]["test_pkg"][1].test
        assert.equals("test_proc", test.name)
        assert.equals("test.ads", test.file)
        assert.equals("100", test.line)
        assert.equals("3", test.column)
      end)

      it("handles multiple test packages in same file", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["test_pkg1"] = { { source = { name = "test1" }, test = {} } },
            ["test_pkg2"] = { { source = { name = "test2" }, test = {} } },
          },
        })
        local file_tests = xml.get_xml_info()["src/my_package.ads"]
        assert.is_not_nil(file_tests["test_pkg1"])
        assert.is_not_nil(file_tests["test_pkg2"])
      end)

      it("handles multiple tests in same package", function()
        set_xml_info({
          ["src/my_package.ads"] = {
            ["test_pkg"] = {
              { source = { name = "test1", line = "10" }, test = {} },
              { source = { name = "test2", line = "20" }, test = {} },
              { source = { name = "test3", line = "30" }, test = {} },
            },
          },
        })
        local pkg_tests = xml.get_xml_info()["src/my_package.ads"]["test_pkg"]
        assert.equals(3, #pkg_tests)
        assert.equals("test1", pkg_tests[1].source.name)
        assert.equals("test2", pkg_tests[2].source.name)
        assert.equals("test3", pkg_tests[3].source.name)
      end)
    end)

    describe("private functions", function()
      it("_query_element returns query object for various inputs", function()
        local inputs = {
          { value = "unit" },
          { value = nil },
          { value = "" },
          { value = "test_unit" },
        }
        for _, input in ipairs(inputs) do
          local query = xml._query_element(input.value)
          assert.is_not_nil(query)
          assert.is_table(query)
        end
      end)
      it("_query_test_info returns a query object", function()
        local query = xml._query_test_info()
        assert.is_not_nil(query)
        assert.is_table(query)
      end)

      it("_create_xml_buf creates buffer and returns buffer id", function()
        local buf_id = xml._create_xml_buf()
        assert.equals(1, buf_id)
      end)

      it(
        "_create_xml_buf executes file pattern matching in vim.fs.find callback",
        function()
          local captured_callback = nil
          _G.vim.fs.find = function(callback)
            captured_callback = callback
            return { "gnattest.xml" }
          end

          xml._create_xml_buf()

          assert.is_not_nil(captured_callback)
          assert.is_function(captured_callback)

          assert.is_true(captured_callback("gnattest.xml"))

          assert.is_false(captured_callback("project_gnattest.xml"))
          assert.is_false(captured_callback("my_gnattest.xml"))
          assert.is_false(captured_callback("/path/to/build/gnattest.xml"))
          assert.is_false(captured_callback("nested/deep/path/gnattest.xml"))

          assert.is_false(captured_callback("test.xml"))
          assert.is_false(captured_callback("gnattest.adb"))
          assert.is_false(captured_callback("gnattest.xml.backup"))
          assert.is_false(captured_callback("gnattest_output.xml"))
        end
      )

      it("_get_pkg_tests returns tests for given package", function()
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["file1.xml"] = {
          ["Package.SubPkg"] = {
            { source = { name = "test1", line = 10 }, test = {} },
            { source = { name = "test2", line = 20 }, test = {} },
          },
        }

        local tests, filename = xml.get_pkg_tests("Package.SubPkg")
        assert.is_not_nil(tests)
        assert.equals("file1.xml", filename)
        assert.equals(2, #tests)
        assert.equals("test1", tests[1].source.name)
        assert.equals("test2", tests[2].source.name)
      end)

      it("_get_pkg_tests returns nil for non-existent package", function()
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["file1.xml"] = {
          ["Package.SubPkg"] = {
            { source = { name = "test1", line = 10 }, test = {} },
          },
        }

        local tests = xml.get_pkg_tests("NonExistent.Package")
        assert.is_nil(tests)
      end)

      it(
        "_get_pkg_tests calls get_xml_info if xml_info table is empty",
        function()
          for k in pairs(xml._xml_info) do
            xml._xml_info[k] = nil
          end

          _G.vim.fs.find = function()
            return {}
          end

          local tests = xml.get_pkg_tests("Any.Package")
          assert.is_nil(tests)
        end
      )
    end)
  end
end)
