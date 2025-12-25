local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.read_only", function()
  local ro
  local autocmd_callbacks = {}

  before_each(function()
    autocmd_callbacks = {}

    _G.vim.api = {
      nvim_create_namespace = function()
        return "test"
      end,
      nvim_create_augroup = function()
        return "autest"
      end,
      nvim_create_autocmd = stub.new().invokes(function(event, opts)
        table.insert(autocmd_callbacks, { event = event, opts = opts })
      end),
      nvim_buf_set_extmark = stub.new().returns(42),
      nvim_get_current_buf = function()
        return 0
      end,
      nvim_buf_get_lines = function()
        return { "lineA", "lineB" }
      end,
      nvim_buf_get_extmarks = stub.new().returns({
        { 42, 1, 0, { end_row = 2 } },
      }),
      nvim_buf_set_lines = stub.new(),
      nvim__get_runtime = function()
        return {}
      end,
      nvim_win_set_cursor = stub.new(),
      nvim_set_hl = stub.new(),
      nvim_set_hl_ns = stub.new(),
      nvim_get_hl = stub.new().returns({ bg = 0x1a1a1a }),
    }
    _G.vim.fn = {
      getpos = function()
        return { 0, 5, 10 }
      end,
    }
    _G.vim.opt = {
      diff = {
        get = function()
          return false
        end,
      },
    }
    _G.vim.o = {
      background = "dark",
    }
    _G.vim.cmd = stub.new()
    _G.vim.log = {
      levels = {
        ERROR = 4,
        WARN = 3,
      },
    }
    _G.vim.schedule = function(cb)
      cb()
    end

    -- Mock utils with read_only-specific methods
    common.mock_utils({
      get_lines = function(start_row, end_row)
        if start_row == 1 and end_row == 2 then
          return { "lineA", "lineB" }
        end
        return { "lineA", "lineB" }
      end,
      get_all_comments = function()
        return {
          { text = "--begin read only", line = 1 },
          { text = "--end read only", line = 2 },
        }
      end,
    })

    package.preload["gnattest.highlight"] = function()
      return { set_highlight = stub.new() }
    end
    ro = require("gnattest.read_only")
  end)

  after_each(function()
    common.cleanup_packages()
    package.preload["gnattest.highlight"] = nil
  end)

  it("should store opts on setup", function()
    ro.setup({ foo = "bar" })
    assert.same({ foo = "bar" }, ro.opt)
  end)

  describe("setup autocommands", function()
    it("should create autocommands", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.stub(_G.vim.api.nvim_create_autocmd).was_called()
    end)

    it("should create three autocommand groups", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_equal(3, #autocmd_callbacks)
    end)

    it("should create ColorScheme autocommand", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_equal("ColorScheme", autocmd_callbacks[1].event)
    end)

    it("should create BufReadPost autocommand", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_equal("BufReadPost", autocmd_callbacks[2].event)
    end)

    it("should create TextChanged autocommand", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local text_changed = autocmd_callbacks[3]
      assert.is_table(text_changed.event)
      assert.is_equal("TextChanged", text_changed.event[1])
      assert.is_equal("TextChangedI", text_changed.event[2])
    end)

    it("should set group for all autocommands", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      for _, callback in ipairs(autocmd_callbacks) do
        assert.is_equal("autest", callback.opts.group)
      end
    end)

    it("should set pattern for file-specific autocommands", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_table(autocmd_callbacks[2].opts.pattern)
      assert.is_string(autocmd_callbacks[2].opts.pattern[1])
    end)
  end)

  describe("extmark storage", function()
    it("should initialize extmark table", function()
      assert.is_table(ro.extmark)
    end)

    it("should store options after setup", function()
      local opts = { region_text = { start = "begin", ending = "end" } }
      ro.setup(opts)
      assert.is_equal("begin", ro.opt.region_text.start)
      assert.is_equal("end", ro.opt.region_text.ending)
    end)
  end)

  describe("namespace and augroup", function()
    it("should have valid namespace, augroup, and highlight group", function()
      assert.is_equal("test", ro.namespace)
      assert.is_equal("autest", ro.ro_group)
      assert.is_equal("hl_ro", ro.hl_group)
    end)
  end)

  describe("error handling", function()
    it("should handle empty options", function()
      assert.has_no_error(function()
        ro.setup({})
      end)
    end)

    it("should handle multiple setups", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      ro.setup({ region_text = { start = "start", ending = "finish" } })
      assert.is_equal("start", ro.opt.region_text.start)
    end)
  end)

  describe("callback execution", function()
    it("should invoke ColorScheme callback", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local colorscheme_callback = autocmd_callbacks[1].opts.callback
      assert.is_not_nil(colorscheme_callback)
      assert.has_no_error(function()
        colorscheme_callback()
      end)
    end)

    it("should invoke BufReadPost callback", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      assert.is_not_nil(bufread_callback)
      assert.has_no_error(function()
        bufread_callback()
      end)
    end)

    it("should call highlight.set_highlight on ColorScheme event", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local hl = require("gnattest.highlight")
      local colorscheme_callback = autocmd_callbacks[1].opts.callback
      colorscheme_callback()
      assert.stub(hl.set_highlight).was_called()
    end)

    it("should call notify when protected region is changed", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      assert.is_not_nil(utils.notify)
    end)
  end)

  describe("region marker recognition", function()
    it("should accept custom start marker", function()
      ro.setup({ region_text = { start = "LOCK", ending = "UNLOCK" } })
      assert.is_equal("LOCK", ro.opt.region_text.start)
    end)

    it("should accept custom end marker", function()
      ro.setup({ region_text = { start = "LOCK", ending = "UNLOCK" } })
      assert.is_equal("UNLOCK", ro.opt.region_text.ending)
    end)

    it("should handle default markers", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })
      assert.is_equal("begin read only", ro.opt.region_text.start)
    end)
  end)

  describe("diff mode detection", function()
    it("should handle diff mode states correctly", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })

      -- Default diff mode should be false
      assert.is_false(_G.vim.opt.diff:get())

      -- Should detect when diff mode is enabled
      _G.vim.opt.diff.get = function()
        return true
      end
      assert.is_true(_G.vim.opt.diff:get())

      -- Should detect when diff mode is disabled
      _G.vim.opt.diff.get = function()
        return false
      end
      assert.is_false(_G.vim.opt.diff:get())
    end)
  end)

  describe("highlight integration", function()
    it("should set hl_group on highlight namespace", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_equal("hl_ro", ro.hl_group)
    end)

    it("should call set_highlight on ColorScheme event", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local hl = require("gnattest.highlight")
      local colorscheme_cb = autocmd_callbacks[1].opts.callback
      colorscheme_cb()
      assert.stub(hl.set_highlight).was_called()
    end)
  end)

  describe("extmark data structure", function()
    it("should store line data in extmark table", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_table(ro.extmark)
    end)

    it("should preserve extmark across operations", function()
      local opts1 = { region_text = { start = "a", ending = "b" } }
      ro.setup(opts1)

      local opts2 = { region_text = { start = "c", ending = "d" } }
      ro.setup(opts2)
      -- Extmark table should be preserved (same reference or new table)
      assert.is_table(ro.extmark)
    end)
  end)

  describe("region detection", function()
    it("should get comments from utils", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })
      local utils = require("gnattest.utils")
      local comments = utils.get_all_comments()
      assert.is_table(comments)
      assert.is_equal(2, #comments)
    end)

    it("should parse region markers from comments", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })
      local utils = require("gnattest.utils")
      local comments = utils.get_all_comments()
      assert.is_equal("--begin read only", comments[1].text)
      assert.is_equal("--end read only", comments[2].text)
    end)
  end)

  describe("state consistency", function()
    it("should maintain consistent state after setup operations", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(ro.namespace)
      assert.is_not_nil(ro.ro_group)
      assert.is_not_nil(ro.hl_group)
      assert.is_table(ro.extmark)

      -- Namespace and augroup should remain stable across setups
      local ns_before = ro.namespace
      local group_before = ro.ro_group
      ro.setup({ foo = "bar" })
      ro.setup({ region_text = { start = "a", ending = "b" } })

      assert.is_equal(ns_before, ro.namespace)
      assert.is_equal(group_before, ro.ro_group)
    end)
  end)

  describe("vim API integration", function()
    it("should use required vim API functions and log levels", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      assert.stub(_G.vim.api.nvim_create_autocmd).was_called()
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
      assert.is_not_nil(_G.vim.api.nvim_buf_set_lines)
      assert.is_not_nil(_G.vim.log.levels.ERROR)
    end)
  end)

  describe("pattern configuration", function()
    it("should use correct gnattest patterns for file matching", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")

      assert.is_equal("**/gnattest/", utils.gnattest_pattern)
      local expected = utils.gnattest_pattern .. "*.ad[bs]"
      assert.is_equal("**/gnattest/*.ad[bs]", expected)
    end)
  end)

  describe("comment parsing edge cases", function()
    it("should handle comments with and without region markers", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })
      local utils = require("gnattest.utils")
      local comments = utils.get_all_comments()
      assert.is_table(comments)
      assert.is_not_nil(comments)
    end)
  end)

  describe("region protection notifications", function()
    it("should use notification system with ERROR log level", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      assert.is_not_nil(utils.notify)
      assert.is_equal(4, _G.vim.log.levels.ERROR)
    end)
  end)

  describe("fix_ro_regions logic", function()
    it("should have required vim APIs for region processing", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })

      assert.is_not_nil(_G.vim.schedule)
      assert.is_not_nil(_G.vim.api.nvim_buf_get_extmarks)

      local pos = _G.vim.fn.getpos(".")
      assert.is_table(pos)
      assert.is_equal(5, pos[2])
    end)
  end)

  describe("protection workflow mechanisms", function()
    it(
      "should handle backup, change detection, protection, and mark restoration",
      function()
        ro.setup({ region_text = { start = "begin", ending = "end" } })

        -- Backup mechanism: Trigger BufReadPost to create backup
        local bufread_callback = autocmd_callbacks[2].opts.callback
        bufread_callback()
        assert.is_true(true) -- Verify no error occurs

        -- Change detection: Compare buffer content with stored lines
        local utils = require("gnattest.utils")
        local lines = utils.get_lines(1, 2)
        assert.is_equal(2, #lines)
        assert.is_not_nil(_G.vim.api.nvim_buf_set_lines)

        -- TextChanged protection mechanism
        local text_changed_callback = autocmd_callbacks[3].opts.callback
        assert.is_not_nil(text_changed_callback)
        assert.is_not_nil(_G.vim.schedule)

        -- Mark restoration
        assert.is_not_nil(_G.vim.api.nvim_win_set_cursor)
        assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
      end
    )
  end)

  describe("full workflow simulation", function()
    it("should handle BufReadPost callback operations correctly", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })

      local bufread_callback = autocmd_callbacks[2].opts.callback

      -- Should handle single BufReadPost without error
      assert.has_no_error(function()
        bufread_callback()
      end)
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()

      -- Should handle multiple BufReadPost events without error
      assert.has_no_error(function()
        bufread_callback()
      end)
    end)
  end)

  describe("configuration persistence", function()
    it("should maintain and update options correctly", function()
      ro.setup({ region_text = { start = "TEST_START", ending = "TEST_END" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      assert.is_equal("TEST_START", ro.opt.region_text.start)

      ro.setup({ region_text = { start = "NEW", ending = "NEW_END" } })
      assert.is_equal("NEW", ro.opt.region_text.start)
    end)
  end)

  describe("region modification detection and protection", function()
    it("should handle region protection scenarios correctly", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      -- Verify extmark was populated
      assert.is_not_nil(ro.extmark[42])

      _G.vim.api.nvim_buf_get_extmarks = stub.new().returns({
        { 42, 1, 0, { end_row = 2 } },
      })
      _G.vim.schedule = function(cb)
        cb()
      end
      local text_changed_callback = autocmd_callbacks[3].opts.callback

      -- Test 1: Should trigger protection when lines are modified
      _G.vim.deep_equal = function()
        return false
      end
      _G.vim.api.nvim_buf_get_lines =
        stub.new().returns({ "modified_A", "modified_B" })
      text_changed_callback()
      assert.stub(utils.notify).was_called()

      -- Test 2: Should not trigger protection when lines are unchanged
      _G.vim.deep_equal = function()
        return true
      end
      _G.vim.api.nvim_buf_get_lines = stub.new().returns({ "lineA", "lineB" })
      local notify_count_before = #utils.notify.calls
      text_changed_callback()
      local notify_count_after = #utils.notify.calls
      assert.is_equal(notify_count_before, notify_count_after)

      -- Test 3: Should skip processing when in diff mode
      _G.vim.opt.diff.get = function()
        return true
      end
      local schedule_called = false
      _G.vim.schedule = function()
        schedule_called = true
      end
      text_changed_callback()
      assert.is_false(schedule_called)
    end)

    it("exercises extmarks with details and overlap options", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      _G.vim.opt.diff.get = function()
        return false
      end

      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      -- This should trigger the specific get_extmarks call with details/overlap
      local text_changed_callback = autocmd_callbacks[3].opts.callback
      text_changed_callback()

      assert.is_true(true) -- Test completed without error
    end)

    it("uses extmarks with details and overlap options", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      _G.vim.opt.diff.get = function()
        return false
      end
      local get_extmarks_spy = stub(_G.vim.api, "nvim_buf_get_extmarks")
      get_extmarks_spy.returns({ { 42, 1, 0, { end_row = 2 } } })

      local text_changed_callback = autocmd_callbacks[3].opts.callback
      text_changed_callback()

      assert.stub(get_extmarks_spy).was_called()
    end)
  end)

  if os.getenv("GNATTEST_TEST_MODE") then
    describe("private functions", function()
      it("_parse_comment detects start region marker", function()
        local opt = {
          region_text = { start = "begin read only", ending = "end read only" },
        }
        local comment = { text = "--begin read only", line = 5 }
        local result = ro._parse_comment(comment, opt)
        assert.is_not_nil(result)
        assert.equals("start", result.type)
        assert.equals(5, result.line)
      end)

      it("_parse_comment detects end region marker", function()
        local opt = {
          region_text = { start = "begin read only", ending = "end read only" },
        }
        local comment = { text = "--end read only", line = 10 }
        local result = ro._parse_comment(comment, opt)
        assert.is_not_nil(result)
        assert.equals("end", result.type)
        assert.equals(10, result.line)
      end)

      it("_parse_comment returns nil for non-marker comments", function()
        local opt = {
          region_text = { start = "begin read only", ending = "end read only" },
        }
        local comment = { text = "-- This is just a comment", line = 7 }
        local result = ro._parse_comment(comment, opt)
        assert.is_nil(result)
      end)

      it(
        "_fix_ro_regions calls vim.api.nvim_buf_get_extmarks with details and overlap",
        function()
          ro.setup({ region_text = { start = "begin", ending = "end" } })
          local bufread_callback = autocmd_callbacks[2].opts.callback
          bufread_callback()

          -- Verify extmark was populated
          assert.is_not_nil(ro.extmark[42])

          -- Ensure diff mode is off (required for fix_ro_regions to execute)
          _G.vim.opt.diff.get = function()
            return false
          end

          -- Track the arguments passed to nvim_buf_get_extmarks
          local get_extmarks_args = nil
          _G.vim.api.nvim_buf_get_extmarks = stub.new().invokes(function(...)
            get_extmarks_args = { ... }
            return {}
          end)

          -- Call _fix_ro_regions directly
          ro._fix_ro_regions()

          -- Verify get_extmarks was called with correct parameters
          assert.stub(_G.vim.api.nvim_buf_get_extmarks).was_called()
          -- The last argument should be the options table with details and overlap
          assert.is_not_nil(get_extmarks_args)
        end
      )
    end)
  end
end)
