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
    package.preload["notify"] = nil
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
end)
