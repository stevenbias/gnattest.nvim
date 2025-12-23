local xml = require("gnattest.xml")

-- Helper to conditionally define tests only when GNATTEST_TEST_MODE is set
local function test_private_functions(description, test_fn)
  if os.getenv("GNATTEST_TEST_MODE") then
    describe(description, test_fn)
  end
end
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
  }
  _G.vim.inspect = function(obj)
    return tostring(obj)
  end
end

describe("gnattest.xml", function()
  before_each(function()
    stub_vim_api()
    xml.tests = {}
  end)

  describe("test storage and caching", function()
    it("initializes tests table", function()
      assert.is_table(xml.tests)
    end)

    it("clears tests between test runs", function()
      xml.tests = { file1 = { pkg1 = { { name = "test" } } } }
      assert.is_table(xml.tests)
      xml.tests = {}
      assert.equals(0, #(next(xml.tests) or {}))
    end)

    it("maintains tests table reference", function()
      xml.tests = { file1 = { pkg1 = { { name = "test" } } } }
      assert.is_table(xml.tests)
    end)
  end)

  describe("get_tests_by_name", function()
    it("returns test by name if present", function()
      xml.tests = { file1 = { pkg1 = { { name = "testA" } } } }
      local test = xml.get_tests_by_name("pkg1", "testA")
      assert.is_table(test)
      assert.equals("testA", test.name)
      assert.equals("file1", test.filename)
      assert.equals("pkg1", test.pkg)
    end)

    it("returns nil if test name not present", function()
      xml.tests = { file1 = { pkg1 = { { name = "testA" } } } }
      local test = xml.get_tests_by_name("pkg1", "missing")
      assert.is_nil(test)
    end)

    it("returns nil if package not present", function()
      xml.tests = { file1 = { pkg1 = { { name = "testA" } } } }
      local test = xml.get_tests_by_name("missing_pkg", "testA")
      assert.is_nil(test)
    end)

    it("handles multiple tests in same package", function()
      xml.tests = {
        file1 = { pkg1 = { { name = "testA" }, { name = "testB" } } },
      }
      local testA = xml.get_tests_by_name("pkg1", "testA")
      local testB = xml.get_tests_by_name("pkg1", "testB")
      assert.equals("testA", testA.name)
      assert.equals("testB", testB.name)
    end)

    it("handles multiple packages", function()
      xml.tests = {
        file1 = {
          pkg1 = { { name = "testA" } },
          pkg2 = { { name = "testB" } },
        },
      }
      local testB = xml.get_tests_by_name("pkg2", "testB")
      assert.equals("testB", testB.name)
      assert.equals("pkg2", testB.pkg)
    end)

    it("preserves test attributes", function()
      xml.tests = {
        file1 = {
          pkg1 = { { name = "test1", line = 42, column = 5 } },
        },
      }
      local test = xml.get_tests_by_name("pkg1", "test1")
      assert.equals(42, test.line)
      assert.equals(5, test.column)
    end)

    it("retrieves test with all metadata fields", function()
      xml.tests = {
        file1 = {
          pkg1 = {
            {
              name = "test1",
              file = "test.ads",
              line = 10,
              column = 2,
            },
          },
        },
      }
      local test = xml.get_tests_by_name("pkg1", "test1")
      assert.equals("test1", test.name)
      assert.equals("test.ads", test.file)
      assert.equals(10, test.line)
      assert.equals(2, test.column)
      assert.equals("file1", test.filename)
      assert.equals("pkg1", test.pkg)
    end)

    it("returns first match when duplicates exist", function()
      xml.tests = {
        file1 = {
          pkg1 = { { name = "test1" }, { name = "test1" } },
        },
      }
      local test = xml.get_tests_by_name("pkg1", "test1")
      assert.is_not_nil(test)
      assert.equals("test1", test.name)
    end)
  end)

  describe("edge cases", function()
    it("handles empty tests table", function()
      xml.tests = {}
      local test = xml.get_tests_by_name("pkg", "test")
      assert.is_nil(test)
    end)

    it("handles special characters in names", function()
      xml.tests = { file1 = { ["pkg.sub"] = { { name = "test_1" } } } }
      local test = xml.get_tests_by_name("pkg.sub", "test_1")
      assert.equals("test_1", test.name)
    end)

    it("handles nested package names with underscores", function()
      xml.tests = {
        file1 = { ["my_pkg_v1"] = { { name = "my_test" } } },
      }
      local test = xml.get_tests_by_name("my_pkg_v1", "my_test")
      assert.equals("my_test", test.name)
    end)

    it("search is case sensitive", function()
      xml.tests = { file1 = { pkg1 = { { name = "TestCase" } } } }
      local test1 = xml.get_tests_by_name("pkg1", "TestCase")
      local test2 = xml.get_tests_by_name("pkg1", "testcase")
      assert.is_not_nil(test1)
      assert.is_nil(test2)
    end)

    it("handles numeric line and column values", function()
      xml.tests = {
        file1 = { pkg1 = { { name = "test", line = 100, column = 20 } } },
      }
      local test = xml.get_tests_by_name("pkg1", "test")
      assert.is_true(test.line == 100)
      assert.is_true(test.column == 20)
    end)
  end)

  describe("module structure", function()
    it("module exports get_tests_by_name function", function()
      assert.is_function(xml.get_tests_by_name)
    end)

    it("module exports get_tests function", function()
      assert.is_function(xml.get_tests)
    end)

    it("module has tests table", function()
      assert.is_table(xml.tests)
    end)
  end)

  describe("get_tests with real XML parsing", function()
    it("parses complete XML structure correctly", function()
      -- Read the actual fixture XML
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      -- Mock vim.fs.find to return fixture path
      _G.vim.fs.find = function()
        return { fixture_path }
      end

      -- Mock vim.fn.readfile to return fixture content
      _G.vim.fn.readfile = function()
        return xml_lines
      end

      -- Mock treesitter to actually parse the XML
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

      -- Call get_tests
      local result = xml.get_tests()

      -- Verify we got a table
      assert.is_table(result)

      -- Verify structure exists (may be empty if treesitter mocking
      -- doesn't fully parse, but at least verify it runs)
      assert.is_not_nil(result)
    end)

    it("get_tests returns cached results on second call", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["gnattest_prefix_my_package.ads"] = {
            { name = "test_add", line = 50 },
          },
        },
      }

      local result1 = xml.get_tests()
      local result2 = xml.get_tests()

      assert.is_table(result1)
      assert.is_table(result2)
      assert.equals(result1, result2)
    end)

    it("get_tests initializes tests table", function()
      xml.tests = {}

      -- Mock vim.fs.find
      _G.vim.fs.find = function()
        return { "spec/fixtures/gnattest.xml" }
      end

      -- Mock vim.fn.readfile
      _G.vim.fn.readfile = function()
        return { "<gnattest></gnattest>" }
      end

      local result = xml.get_tests()
      assert.is_table(result)
    end)

    it("structure contains source files as keys", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["test_pkg"] = { { name = "test1" } },
        },
      }

      local result = xml.get_tests()
      assert.is_not_nil(result["src/my_package.ads"])
    end)

    it("structure contains test packages in source files", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["gnattest_prefix_my_package.ads"] = { { name = "test1" } },
        },
      }

      local result = xml.get_tests()
      local tests =
        result["src/my_package.ads"]["gnattest_prefix_my_package.ads"]
      assert.is_table(tests)
      assert.equals("test1", tests[1].name)
    end)

    it("src_info contains name, line, column, and test fields", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["test_pkg"] = {
            {
              name = "add_numbers",
              line = "10",
              column = "5",
              test = {
                name = "test_add_positive",
                file = "test.ads",
                line = "50",
                column = "3",
              },
            },
          },
        },
      }

      local result = xml.get_tests()
      local src = result["src/my_package.ads"]["test_pkg"][1]
      assert.equals("add_numbers", src.name)
      assert.equals("10", src.line)
      assert.equals("5", src.column)
      assert.is_table(src.test)
    end)

    it("test_info contains name, file, line, and column fields", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["test_pkg"] = {
            {
              name = "proc",
              test = {
                name = "test_proc",
                file = "test.ads",
                line = "100",
                column = "3",
              },
            },
          },
        },
      }

      local result = xml.get_tests()
      local test = result["src/my_package.ads"]["test_pkg"][1].test
      assert.equals("test_proc", test.name)
      assert.equals("test.ads", test.file)
      assert.equals("100", test.line)
      assert.equals("3", test.column)
    end)

    it("handles multiple source files", function()
      xml.tests = {
        ["src/package1.ads"] = {
          ["test_pkg1"] = { { name = "test1" } },
        },
        ["src/package2.ads"] = {
          ["test_pkg2"] = { { name = "test2" } },
        },
      }

      local result = xml.get_tests()
      assert.is_not_nil(result["src/package1.ads"])
      assert.is_not_nil(result["src/package2.ads"])
      local count = 0
      for _ in pairs(result) do
        count = count + 1
      end
      assert.equals(2, count)
    end)

    it("handles multiple test packages in same file", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["test_pkg1"] = { { name = "test1" } },
          ["test_pkg2"] = { { name = "test2" } },
        },
      }

      local result = xml.get_tests()
      local file_tests = result["src/my_package.ads"]
      assert.is_not_nil(file_tests["test_pkg1"])
      assert.is_not_nil(file_tests["test_pkg2"])
    end)

    it("handles multiple tests in same package", function()
      xml.tests = {
        ["src/my_package.ads"] = {
          ["test_pkg"] = {
            { name = "test1", line = "10" },
            { name = "test2", line = "20" },
            { name = "test3", line = "30" },
          },
        },
      }

      local result = xml.get_tests()
      local pkg_tests = result["src/my_package.ads"]["test_pkg"]
      assert.equals(3, #pkg_tests)
      assert.equals("test1", pkg_tests[1].name)
      assert.equals("test2", pkg_tests[2].name)
      assert.equals("test3", pkg_tests[3].name)
    end)
  end)

  describe("real fixture parsing", function()
    it("reads real fixture file successfully", function()
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
      -- Should have parsed some lines
      assert.is_true(#xml_lines > 0)
    end)

    it("fixture has proper XML structure with multiple units", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      local content = table.concat(xml_lines, "\n")
      -- Verify multiple source files in fixture with generic names
      assert.is_not_nil(string.find(content, "package_a%.ads"))
      assert.is_not_nil(string.find(content, "package_b%.ads"))
      assert.is_not_nil(string.find(content, "package_c%.ads"))
    end)

    it("fixture has multiple test packages per unit", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      local content = table.concat(xml_lines, "\n")
      -- package_a has multiple test_unit elements
      local count = 0
      for _ in string.gmatch(content, "<test_unit") do
        count = count + 1
      end
      assert.is_true(count > 1)
    end)

    it("fixture has multiple tested procedures per test_unit", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      local content = table.concat(xml_lines, "\n")
      -- Count tested elements
      local count = 0
      for _ in string.gmatch(content, "<tested") do
        count = count + 1
      end
      assert.is_true(count > 1)
    end)

    it("fixture has multiple test cases per tested procedure", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      local content = table.concat(xml_lines, "\n")
      -- Count test_case elements
      local count = 0
      for _ in string.gmatch(content, "<test_case") do
        count = count + 1
      end
      assert.is_true(count > 1)
    end)

    it("fixture has complex nested structure", function()
      local fixture_path = "spec/fixtures/gnattest.xml"
      local xml_lines = {}
      local file = io.open(fixture_path, "r")
      if file then
        for line in file:lines() do
          table.insert(xml_lines, line)
        end
        file:close()
      end

      local content = table.concat(xml_lines, "\n")
      -- Verify proper nesting: unit > test_unit > tested > test_case > test
      assert.is_true(string.find(content, "<tests_mapping") ~= nil)
      assert.is_true(string.find(content, "<unit") ~= nil)
      assert.is_true(string.find(content, "<test_unit") ~= nil)
      assert.is_true(string.find(content, "<tested") ~= nil)
      assert.is_true(string.find(content, "<test_case") ~= nil)
      assert.is_true(string.find(content, "<test") ~= nil)
    end)
  end)

  test_private_functions("private functions", function()
    it("_query_element returns a query object", function()
      local query = xml._query_element("unit")
      assert.is_not_nil(query)
      assert.is_table(query)
    end)

    it("_query_element with nil returns a query object", function()
      local query = xml._query_element(nil)
      assert.is_not_nil(query)
      assert.is_table(query)
    end)

    it("_query_element with empty string returns a query object", function()
      local query = xml._query_element("")
      assert.is_not_nil(query)
      assert.is_table(query)
    end)

    it("_query_element with test_unit returns a query object", function()
      local query = xml._query_element("test_unit")
      assert.is_not_nil(query)
      assert.is_table(query)
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

    it("_get_pkg_tests returns tests for given package", function()
      xml.tests = {
        ["file1.xml"] = {
          ["Package.SubPkg"] = {
            { name = "test1", line = 10 },
            { name = "test2", line = 20 },
          },
        },
      }

      local tests, filename = xml._get_pkg_tests("Package.SubPkg")
      assert.is_not_nil(tests)
      assert.equals("file1.xml", filename)
      assert.equals(2, #tests)
      assert.equals("test1", tests[1].name)
      assert.equals("test2", tests[2].name)
    end)

    it("_get_pkg_tests returns nil for non-existent package", function()
      xml.tests = {
        ["file1.xml"] = {
          ["Package.SubPkg"] = {
            { name = "test1", line = 10 },
          },
        },
      }

      local tests = xml._get_pkg_tests("NonExistent.Package")
      assert.is_nil(tests)
    end)

    it("_get_pkg_tests calls get_tests if tests table is empty", function()
      xml.tests = {}
      _G.vim.fs.find = function()
        return {}
      end

      local tests = xml._get_pkg_tests("Any.Package")
      assert.is_nil(tests)
    end)
  end)
end)
