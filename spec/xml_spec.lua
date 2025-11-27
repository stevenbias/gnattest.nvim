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
  }
  _G.vim.deepcopy = function(tbl)
    -- return a simple shallow copy for test
    local cp = {}
    for k, v in pairs(tbl) do
      cp[k] = v
    end
    return cp
  end
  _G.vim.inspect = function(obj)
    return tostring(obj)
  end
end

describe("gnattest.xml", function()
  before_each(function()
    stub_vim_api()
    xml.tests = {}
  end)

  describe("query functions", function()
    it("query_element handles nil match parameter", function()
      local q = xml.query_element(nil)
      assert.is_table(q)
      assert.is_function(q.iter_captures)
      assert.is_table(q.captures)
    end)

    it("query_element returns a treesitter query object", function()
      local q = xml.query_element("unit")
      assert.is_table(q)
      assert.is_function(q.iter_captures)
      assert.is_table(q.captures)
    end)

    it("query_element with special characters", function()
      local q = xml.query_element("test_unit")
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_test_info returns a treesitter query object", function()
      local q = xml.query_test_info()
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_att_value handles nil parameter", function()
      local q = xml.query_att_value(nil)
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_att_value returns a treesitter query object", function()
      local q = xml.query_att_value("unit")
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_subpr_by_pkg handles nil parameter", function()
      local q = xml.query_subpr_by_pkg(nil)
      assert.is_table(q)
    end)

    it("query_subpr_by_pkg returns a treesitter query object", function()
      local q = xml.query_subpr_by_pkg("pkg1")
      assert.is_table(q)
    end)

    it("query_test_info_by_subpr handles nil parameter", function()
      local q = xml.query_test_info_by_subpr(nil)
      assert.is_table(q)
    end)

    it("query_test_info_by_subpr returns a treesitter query object", function()
      local q = xml.query_test_info_by_subpr("subpr1")
      assert.is_table(q)
    end)
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

    it("module exports query functions", function()
      assert.is_function(xml.query_element)
      assert.is_function(xml.query_test_info)
      assert.is_function(xml.query_att_value)
      assert.is_function(xml.query_subpr_by_pkg)
      assert.is_function(xml.query_test_info_by_subpr)
    end)

    it("module has tests table", function()
      assert.is_table(xml.tests)
    end)
  end)
end)
