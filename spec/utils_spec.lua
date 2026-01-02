local stub = require("luassert.stub")
local helpers = require("spec.helpers.common")

describe("gnattest.utils", function()
  local utils

  before_each(function()
    -- Use helper to setup basic vim API, then extend it
    _G.vim = _G.vim or {}
    _G.vim.api = helpers.create_basic_vim_api({
      nvim_echo = function(msg)
        return msg
      end,
      nvim_get_current_buf = function()
        return 0
      end,
      nvim_buf_get_lines = function()
        return { "line1", "line2" }
      end,
      nvim__get_runtime = function()
        return {}
      end,
    })
    _G.vim.fn = helpers.create_vim_fn_mock({
      expand = function(_)
        return "gnattest/gnattest_file.adb"
      end,
    })
    -- Stub Treesitter as used by utils.lua
    _G.vim.treesitter = {
      get_parser = function(_, lang)
        if lang == "ada" then
          return {
            parse = function()
              -- mimic parse tree with root
              return {
                {
                  root = function()
                    return 99
                  end,
                },
              }
            end,
          }
        end
        error("No parser")
      end,
      query = {
        parse = function()
          return {
            iter_captures = function()
              -- Stub node object
              local node = {
                range = function()
                  return 7, 7, 0, 0
                end, -- typical return: start_row, end_row, start_col, end_col
              }
              local id = 1
              return coroutine.wrap(function()
                coroutine.yield(id, node)
              end)
            end,
            captures = { "comment" },
          }
        end,
      },
      get_node_text = function(_, _)
        return "--begin read only"
      end,
    }
    -- Stub vim.fs if used anywhere by utils.lua or its dependencies
    _G.vim.fs = {
      find = function(_)
        return {}
      end,
      dirname = function(_)
        return "gnattest"
      end,
    }
    -- Stub notify plugin and vim.notify
    package.preload["notify"] = function()
      return stub.new()
    end

    utils = require("gnattest.utils")
  end)

  after_each(function()
    package.loaded["gnattest.utils"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.preload["notify"] = nil
    package.preload["gnattest.ada_ls"] = nil
  end)

  it("does not use vim.notify when notify module is loaded", function()
    local s = spy.on(vim, "notify")
    utils.is_loaded = function()
      return true
    end
    utils.notify("foo", "warn")
    assert.spy(s).was.called(0)
  end)

  it("notifies using vim.notify when notify module is not present", function()
    local s = spy.on(vim, "notify")
    utils.is_loaded = function()
      return false
    end
    utils.notify("bar", "info")
    assert.spy(s).was.called(1)
  end)

  it("is_loaded returns true for existing modules", function()
    -- luassert is a test dependency that should be loaded
    local result = utils.is_loaded("luassert")
    assert.is_true(result)
  end)

  it("is_loaded returns false for non-existent modules", function()
    -- This module should not exist
    local result = utils.is_loaded("nonexistent_module_that_does_not_exist")
    assert.is_false(result)
  end)

  it("returns current buffer id", function()
    assert.equals(0, utils.get_bufid())
  end)

  it("detects gnattest file path", function()
    assert.is_true(utils.is_gnattest_file())
  end)

  it("returns lines from get_lines", function()
    assert.are.same({ "line1", "line2" }, utils.get_lines(0, 1))
  end)

  it("returns comments via get_all_comments", function()
    local comments = utils.get_all_comments("ada")
    assert.truthy(comments)
    assert.same("--begin read only", comments[1].text)
  end)

  it("handles missing ada treesitter parser gracefully", function()
    _G.vim.treesitter.get_parser = function(_, lang)
      if lang == "ada" then
        return nil
      end
      error("No parser")
    end
    utils = require("gnattest.utils")

    local comments = utils.get_all_comments("ada")
    assert.same({}, comments)
  end)

  it("handles treesitter query parse failure gracefully", function()
    _G.vim.treesitter.query.parse = function()
      return nil
    end
    utils = require("gnattest.utils")

    local comments = utils.get_all_comments("ada")
    assert.same({}, comments)
  end)

  it("handles failed parser pcall", function()
    _G.vim.treesitter.get_parser = function()
      error("Parser error")
    end
    utils = require("gnattest.utils")

    local comments = utils.get_all_comments("ada")
    assert.same({}, comments)
  end)

  it("returns get_bufpath via fn.expand", function()
    assert.same("gnattest/gnattest_file.adb", utils.get_bufpath())
  end)

  it("returns get_bufdir via fs.dirname", function()
    assert.same("gnattest", utils.get_bufdir())
  end)

  if helpers.should_test_private_functions() then
    describe("private functions", function()
      local log_level_cases = {
        { 0, "TRACE" },
        { 1, "DEBUG" },
        { 2, "INFO" },
        { 3, "WARN" },
        { 4, "ERROR" },
        { 5, "OFF" },
        { 99, "ERROR" },
        { -1, "ERROR" },
      }
      for _, case in ipairs(log_level_cases) do
        it(
          "_log_lvl_tostring returns " .. case[2] .. " for level " .. case[1],
          function()
            assert.equals(case[2], utils._log_lvl_tostring(case[1]))
          end
        )
      end

      it("_get_parser returns parser when ada parser exists", function()
        local parser = utils._get_parser()
        assert.is_not_nil(parser)
        assert.is_function(parser.parse)
      end)

      it("_get_parser returns nil when ada parser fails", function()
        _G.vim.treesitter.get_parser = function(_, lang)
          if lang == "ada" then
            error("No parser available")
          end
        end
        utils = require("gnattest.utils")
        local parser = utils._get_parser()
        assert.is_nil(parser)
      end)

      it("_get_root returns root node when parser succeeds", function()
        local root = utils._get_root()
        assert.is_not_nil(root)
        assert.equals(99, root)
      end)

      it("_get_root returns nil when parser fails", function()
        _G.vim.treesitter.get_parser = function()
          error("No parser")
        end
        utils = require("gnattest.utils")
        local root = utils._get_root()
        assert.is_nil(root)
      end)
    end)
  end

  describe("get_filename()", function()
    it("returns basename of buffer path", function()
      _G.vim.fn.expand = function()
        return "/path/to/my_file.adb"
      end
      _G.vim.fs.basename = function(path)
        return path:match("([^/]+)$")
      end
      assert.equals("my_file.adb", utils.get_filename())
    end)
  end)

  describe("is_gnattest_file() alternative detection", function()
    it("detects file in harness_dir when gnattest not in path", function()
      package.loaded["gnattest.utils"] = nil
      _G.vim.fn.expand = function()
        return "/project/obj/harness/test.adb"
      end
      _G.vim.fs.dirname = function()
        return "/project/obj/harness"
      end
      package.preload["gnattest.ada_ls"] = function()
        return {
          get_harness_dir = function()
            return "/project/obj/harness"
          end,
          get_tests_dir = function()
            return "/project/obj/tests"
          end,
        }
      end
      local test_utils = require("gnattest.utils")
      assert.is_true(test_utils.is_gnattest_file())
    end)
  end)

  describe("set_gnattest_pattern()", function()
    local function setup_ada_ls()
      package.loaded["gnattest.utils"] = nil
      package.preload["gnattest.ada_ls"] = function()
        return {
          get_harness_dir = function()
            return "/project/harness"
          end,
          get_tests_dir = function()
            return "/project/tests"
          end,
        }
      end
      return require("gnattest.utils")
    end

    it("populates pattern on first call", function()
      local test_utils = setup_ada_ls()
      test_utils.set_gnattest_pattern()
      assert.equals(3, #test_utils.gnattest_pattern)
      assert.is_true(
        test_utils.gnattest_pattern[2]:find("/project/harness") ~= nil
      )
    end)

    it("returns cached pattern on subsequent calls", function()
      local test_utils = setup_ada_ls()
      test_utils.set_gnattest_pattern()
      local count_before = #test_utils.gnattest_pattern
      local result = test_utils.set_gnattest_pattern()
      assert.equals(count_before, #test_utils.gnattest_pattern)
      assert.same(test_utils.gnattest_pattern, result)
    end)
  end)

  describe("find_file()", function()
    it("finds file in list of paths", function()
      _G.vim.islist = function(t)
        return type(t) == "table" and t[1] ~= nil
      end
      _G.vim.fs.find = stub.new().returns({ "/path1/file.ads" })
      assert.equals(
        "/path1/file.ads",
        utils.find_file("file.ads", { "/path1", "/path2" })
      )
    end)

    it("finds file with single path string", function()
      package.loaded["gnattest.utils"] = nil
      _G.vim.islist = function()
        return false
      end
      _G.vim.fs.find = stub.new().returns({ "/path/file.ads" })
      local test_utils = require("gnattest.utils")
      assert.equals("/path/file.ads", test_utils.find_file("file.ads", "/path"))
    end)

    it("returns nil when file not found", function()
      _G.vim.islist = function(t)
        return type(t) == "table" and t[1] ~= nil
      end
      _G.vim.fs.find = stub.new().returns({})
      assert.is_nil(utils.find_file("nonexistent.ads", { "/path1", "/path2" }))
    end)
  end)
end)
