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
    xml.gnattest_info = {}
  end)

  describe("query functions", function()
    it("query_element returns a treesitter query object", function()
      local q = xml.query_element("unit")
      assert.is_table(q)
      assert.is_function(q.iter_captures)
      assert.is_table(q.captures)
    end)

    it("query_test_info returns a treesitter query object", function()
      local q = xml.query_test_info()
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_att_value returns a treesitter query object", function()
      local q = xml.query_att_value("unit")
      assert.is_table(q)
      assert.is_function(q.iter_captures)
    end)

    it("query_subpr_by_pkg returns a treesitter query object", function()
      local q = xml.query_subpr_by_pkg("pkg1")
      assert.is_table(q)
    end)

    it("query_test_info_by_subpr returns a treesitter query object", function()
      local q = xml.query_test_info_by_subpr("subpr1")
      assert.is_table(q)
    end)
  end)

  -- describe("get_tests_by_name", function()
  --     it("returns test by name if present", function()
  --       xml.gnattest_info = { file1 = { pkg1 = { source = { name = "testA" } } } }
  --       local test = xml.get_tests_by_name("pkg1", "testA")
  --       assert.is_table(test)
  --       assert.equals("testA", test.source.name)
  --       assert.equals("file1", test.source.filename)
  --       assert.equals("pkg1", test.pkg)
  --     end)
  --
  --   it("returns nil if test name not present", function()
  --     xml.gnattest_info = { file1 = { pkg1 = { { name = "testA" } } } }
  --     local test = xml.get_tests_by_name("pkg1", "missing")
  --     assert.is_nil(test)
  --   end)
  -- end)
end)
