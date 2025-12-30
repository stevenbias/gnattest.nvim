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

describe("gnattest.xml", function()
  before_each(function()
    stub_vim_api()
    package.loaded["gnattest.xml"] = nil
    xml = require("gnattest.xml")
  end)

  describe("module structure", function()
    it("exports required functions", function()
      assert.is_function(xml.get_tests_by_name)
      assert.is_function(xml.get_xml_info)
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
  end)

  describe("real fixture parsing", function()
    it("validates fixture file XML structure and content", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      assert.is_not_nil(file)
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      assert.is_true(#xml_lines > 0)
      local content = table.concat(xml_lines, "\n")

      -- Verify multiple source files
      assert.is_not_nil(string.find(content, "package_a%.ads"))
      assert.is_not_nil(string.find(content, "package_b%.ads"))
      assert.is_not_nil(string.find(content, "package_c%.ads"))

      -- Count test_unit elements (should be multiple)
      local test_unit_count = 0
      for _ in string.gmatch(content, "<test_unit") do
        test_unit_count = test_unit_count + 1
      end
      assert.is_true(test_unit_count > 1)

      -- Count tested elements (should be multiple)
      local tested_count = 0
      for _ in string.gmatch(content, "<tested") do
        tested_count = tested_count + 1
      end
      assert.is_true(tested_count > 1)

      -- Count test_case elements (should be multiple)
      local test_case_count = 0
      for _ in string.gmatch(content, "<test_case") do
        test_case_count = test_case_count + 1
      end
      assert.is_true(test_case_count > 1)

      -- Verify proper nesting structure
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

      -- Directly populate xml_info (only available when _xml_info is exported)
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
        local result, filename = xml.get_tests_by_name("pkg1", "testA")
        assert.is_table(result)
        assert.equals("testA", result.source.name)
        assert.equals("file1", filename)
      end)

      it("returns nil if test name not present", function()
        xml = inject_xml_data({
          file1 = { pkg1 = { { source = { name = "testA" }, test = {} } } },
        })
        local result = xml.get_tests_by_name("pkg1", "missing")
        assert.is_nil(result)
      end)

      it("returns nil if package not present", function()
        xml = inject_xml_data({
          file1 = { pkg1 = { { source = { name = "testA" }, test = {} } } },
        })
        local result = xml.get_tests_by_name("missing_pkg", "testA")
        assert.is_nil(result)
      end)

      it("handles multiple tests in same package", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              { source = { name = "testA" }, test = {} },
              { source = { name = "testB" }, test = {} },
            },
          },
        })
        local testA, _ = xml.get_tests_by_name("pkg1", "testA")
        local testB, _ = xml.get_tests_by_name("pkg1", "testB")
        assert.equals("testA", testA.source.name)
        assert.equals("testB", testB.source.name)
      end)

      it("handles multiple packages", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = { { source = { name = "testA" }, test = {} } },
            pkg2 = { { source = { name = "testB" }, test = {} } },
          },
        })
        local testB, filename = xml.get_tests_by_name("pkg2", "testB")
        assert.equals("testB", testB.source.name)
        assert.equals("file1", filename)
      end)

      it("preserves test attributes", function()
        xml = inject_xml_data({
          file1 = {
            pkg1 = {
              {
                source = { name = "test1", line = "42", column = "5" },
                test = {},
              },
            },
          },
        })
        local result, _ = xml.get_tests_by_name("pkg1", "test1")
        assert.equals("42", result.source.line)
        assert.equals("5", result.source.column)
      end)

      it("retrieves test with all metadata fields", function()
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
        local result, filename = xml.get_tests_by_name("pkg1", "test1")
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
        local result = xml.get_tests_by_name("pkg1", "test1")
        assert.is_not_nil(result)
        assert.equals("test1", result.source.name)
      end)
    end)

    describe("edge cases", function()
      it("handles empty tests table", function()
        xml = inject_xml_data({})
        local result = xml.get_tests_by_name("pkg", "test")
        assert.is_nil(result)
      end)

      it("handles special characters in names", function()
        xml = inject_xml_data({
          file1 = {
            ["pkg.sub"] = { { source = { name = "test_1" }, test = {} } },
          },
        })
        local result, _ = xml.get_tests_by_name("pkg.sub", "test_1")
        assert.equals("test_1", result.source.name)
      end)

      it("handles nested package names with underscores", function()
        xml = inject_xml_data({
          file1 = {
            ["my_pkg_v1"] = { { source = { name = "my_test" }, test = {} } },
          },
        })
        local result, _ = xml.get_tests_by_name("my_pkg_v1", "my_test")
        assert.equals("my_test", result.source.name)
      end)

      it("search is case sensitive", function()
        xml = inject_xml_data({
          file1 = { pkg1 = { { source = { name = "TestCase" }, test = {} } } },
        })
        local result1, _ = xml.get_tests_by_name("pkg1", "TestCase")
        local result2 = xml.get_tests_by_name("pkg1", "testcase")
        assert.is_not_nil(result1)
        assert.is_nil(result2)
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
        local result, _ = xml.get_tests_by_name("pkg1", "test")
        assert.equals("100", result.source.line)
        assert.equals("20", result.source.column)
      end)
    end)

    describe("xml_info internal state tests", function()
      it("get_xml_info returns cached results on second call", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
          ["gnattest_prefix_my_package.ads"] = {
            { name = "test_add", line = 50 },
          },
        }

        local result1 = xml.get_xml_info()
        local result2 = xml.get_xml_info()

        assert.is_table(result1)
        assert.is_table(result2)
        assert.equals(result1, result2)
      end)

      it("structure contains source files and test packages", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
          ["test_pkg"] = { { source = { name = "test1" }, test = {} } },
          ["gnattest_prefix_my_package.ads"] = {
            { source = { name = "test2" }, test = {} },
          },
        }

        local result = xml.get_xml_info()
        assert.is_not_nil(result["src/my_package.ads"])
        local pkg_tests =
          result["src/my_package.ads"]["gnattest_prefix_my_package.ads"]
        assert.is_table(pkg_tests)
        assert.equals("test2", pkg_tests[1].source.name)
      end)

      it("handles multiple source files", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/package1.ads"] = {
          ["test_pkg1"] = { { source = { name = "test1" }, test = {} } },
        }
        xml._xml_info["src/package2.ads"] = {
          ["test_pkg2"] = { { source = { name = "test2" }, test = {} } },
        }

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
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
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
        }

        local result = xml.get_xml_info()
        local src = result["src/my_package.ads"]["test_pkg"][1].source
        assert.equals("add_numbers", src.name)
        assert.equals("10", src.line)
        assert.equals("5", src.column)
        assert.is_table(result["src/my_package.ads"]["test_pkg"][1].test)
      end)

      it("test_info contains name, file, line, and column fields", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
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
        }

        local result = xml.get_xml_info()
        local test = result["src/my_package.ads"]["test_pkg"][1].test
        assert.equals("test_proc", test.name)
        assert.equals("test.ads", test.file)
        assert.equals("100", test.line)
        assert.equals("3", test.column)
      end)

      it("handles multiple test packages in same file", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
          ["test_pkg1"] = { { source = { name = "test1" }, test = {} } },
          ["test_pkg2"] = { { source = { name = "test2" }, test = {} } },
        }

        local result = xml.get_xml_info()
        local file_tests = result["src/my_package.ads"]
        assert.is_not_nil(file_tests["test_pkg1"])
        assert.is_not_nil(file_tests["test_pkg2"])
      end)

      it("handles multiple tests in same package", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["src/my_package.ads"] = {
          ["test_pkg"] = {
            { source = { name = "test1", line = "10" }, test = {} },
            { source = { name = "test2", line = "20" }, test = {} },
            { source = { name = "test3", line = "30" }, test = {} },
          },
        }

        local result = xml.get_xml_info()
        local pkg_tests = result["src/my_package.ads"]["test_pkg"]
        assert.equals(3, #pkg_tests)
        assert.equals("test1", pkg_tests[1].source.name)
        assert.equals("test2", pkg_tests[2].source.name)
        assert.equals("test3", pkg_tests[3].source.name)
      end)
    end)

    describe("private functions", function()
      it("_query_element handles nil parameter correctly", function()
        -- This test specifically targets line 7: match = ""
        local query = xml._query_element(nil)
        assert.is_not_nil(query)
        assert.is_table(query)
      end)

      local query_element_inputs = { "unit", nil, "", "test_unit" }
      for _, input in ipairs(query_element_inputs) do
        it(
          "_query_element with " .. tostring(input) .. " returns a query object",
          function()
            local query = xml._query_element(input)
            assert.is_not_nil(query)
            assert.is_table(query)
          end
        )
      end

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

          -- Call _create_xml_buf to capture the callback
          xml._create_xml_buf()

          -- Verify we captured the callback
          assert.is_not_nil(captured_callback)
          assert.is_function(captured_callback)

          -- Test the strict equality check - should only match exact "gnattest.xml"
          assert.is_true(captured_callback("gnattest.xml"))

          -- Should not match files with gnattest.xml as suffix
          assert.is_false(captured_callback("project_gnattest.xml"))
          assert.is_false(captured_callback("my_gnattest.xml"))
          assert.is_false(captured_callback("/path/to/build/gnattest.xml"))
          assert.is_false(captured_callback("nested/deep/path/gnattest.xml"))

          -- Should not match other files
          assert.is_false(captured_callback("test.xml"))
          assert.is_false(captured_callback("gnattest.adb"))
          assert.is_false(captured_callback("gnattest.xml.backup"))
          assert.is_false(captured_callback("gnattest_output.xml"))
        end
      )

      it("_get_pkg_tests returns tests for given package", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["file1.xml"] = {
          ["Package.SubPkg"] = {
            { source = { name = "test1", line = 10 }, test = {} },
            { source = { name = "test2", line = 20 }, test = {} },
          },
        }

        local tests, filename = xml._get_pkg_tests("Package.SubPkg")
        assert.is_not_nil(tests)
        assert.equals("file1.xml", filename)
        assert.equals(2, #tests)
        assert.equals("test1", tests[1].source.name)
        assert.equals("test2", tests[2].source.name)
      end)

      it("_get_pkg_tests returns nil for non-existent package", function()
        -- Populate xml_info through the exported reference
        for k in pairs(xml._xml_info) do
          xml._xml_info[k] = nil
        end
        xml._xml_info["file1.xml"] = {
          ["Package.SubPkg"] = {
            { source = { name = "test1", line = 10 }, test = {} },
          },
        }

        local tests = xml._get_pkg_tests("NonExistent.Package")
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

          local tests = xml._get_pkg_tests("Any.Package")
          assert.is_nil(tests)
        end
      )
    end)
  end
end)
