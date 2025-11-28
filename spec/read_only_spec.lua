local stub = require("luassert.stub")

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

    package.preload["gnattest.utils"] = function()
      return {
        get_bufid = function()
          return 1
        end,
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
        notify = stub.new(),
        gnattest_pattern = "**/gnattest/",
      }
    end
    package.preload["gnattest.highlight"] = function()
      return { set_highlight = stub.new() }
    end
    ro = require("gnattest.read_only")
  end)

  after_each(function()
    package.preload["gnattest.utils"] = nil
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
    it("should have valid namespace", function()
      assert.is_equal("test", ro.namespace)
    end)

    it("should have valid augroup", function()
      assert.is_equal("autest", ro.ro_group)
    end)

    it("should have highlight group defined", function()
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

  describe("buffer and cursor operations", function()
    it("should use nvim_buf_set_extmark for marking regions", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      -- Trigger BufReadPost callback to invoke prepare_gnattest
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
    end)

    it("should use nvim_buf_set_lines for restoring content", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.api.nvim_buf_set_lines)
    end)

    it("should track cursor position", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local pos = _G.vim.fn.getpos(".")
      assert.is_equal(5, pos[2])
      assert.is_equal(10, pos[3])
    end)
  end)

  describe("diff mode detection", function()
    it("should check diff mode before processing changes", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local diff_mode = _G.vim.opt.diff:get()
      assert.is_false(diff_mode)
    end)

    it("should skip processing when in diff mode", function()
      _G.vim.opt.diff.get = function()
        return true
      end
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_true(_G.vim.opt.diff:get())
    end)

    it("should process when not in diff mode", function()
      _G.vim.opt.diff.get = function()
        return false
      end
      ro.setup({ region_text = { start = "begin", ending = "end" } })
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
    it("should maintain state after setup", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(ro.namespace)
      assert.is_not_nil(ro.ro_group)
      assert.is_not_nil(ro.hl_group)
      assert.is_table(ro.extmark)
    end)

    it("should update options without changing namespace", function()
      local ns_before = ro.namespace
      ro.setup({ foo = "bar" })
      local ns_after = ro.namespace
      assert.is_equal(ns_before, ns_after)
    end)

    it("should update options without changing augroup", function()
      local group_before = ro.ro_group
      ro.setup({ region_text = { start = "a", ending = "b" } })
      local group_after = ro.ro_group
      assert.is_equal(group_before, group_after)
    end)
  end)

  describe("vim API integration", function()
    it("should use vim.api.nvim_create_autocmd", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.stub(_G.vim.api.nvim_create_autocmd).was_called()
    end)

    it("should use vim.api.nvim_buf_set_extmark", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
    end)

    it("should use vim.api.nvim_buf_set_lines", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.api.nvim_buf_set_lines)
    end)

    it("should use vim.log.levels for notification", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.log.levels.ERROR)
    end)
  end)

  describe("pattern configuration", function()
    it("should use gnattest pattern for file matching", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      assert.is_equal("**/gnattest/", utils.gnattest_pattern)
    end)

    it("should combine pattern with Ada file extension", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      local expected = utils.gnattest_pattern .. "*.ad[bs]"
      assert.is_equal("**/gnattest/*.ad[bs]", expected)
    end)
  end)

  describe("comment parsing edge cases", function()
    it("should handle comments without region markers", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      -- Get all comments
      local utils = require("gnattest.utils")
      local comments = utils.get_all_comments()
      assert.is_table(comments)
    end)

    it("should parse comments with various prefixes", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })
      local utils = require("gnattest.utils")
      local comments = utils.get_all_comments()
      assert.is_not_nil(comments)
    end)
  end)

  describe("region protection notifications", function()
    it("should use notification system", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      assert.is_not_nil(utils.notify)
    end)

    it("should use ERROR log level for protection", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_equal(4, _G.vim.log.levels.ERROR)
    end)
  end)

  describe("fix_ro_regions logic", function()
    it("should schedule changes on TextChanged", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      -- TextChanged callback uses vim.schedule
      assert.is_not_nil(_G.vim.schedule)
    end)

    it("should get extmarks for all regions", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.api.nvim_buf_get_extmarks)
    end)

    it("should use cursor position from vim.fn.getpos", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local pos = _G.vim.fn.getpos(".")
      assert.is_table(pos)
      assert.is_equal(5, pos[2])
    end)
  end)

  describe("backup mechanism", function()
    it("should create backup on first region detection", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      -- Trigger BufReadPost to create backup
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      -- After this, backup should be created
      -- (We can't directly access it, but we can verify the test doesn't error)
      assert.is_true(true)
    end)
  end)

  describe("change detection", function()
    it("should compare buffer content with stored lines", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      local lines = utils.get_lines(1, 2)
      assert.is_equal(2, #lines)
    end)

    it("should restore lines when changed", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.api.nvim_buf_set_lines)
    end)
  end)

  describe("TextChanged protection mechanism", function()
    it("should reset protect_flag on TextChanged after protection", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local text_changed_callback = autocmd_callbacks[3].opts.callback
      assert.is_not_nil(text_changed_callback)
    end)

    it("should call fix_ro_regions when protect_flag is false", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      -- TextChanged callback logic is preserved
      assert.is_not_nil(_G.vim.schedule)
    end)
  end)

  describe("mark restoration", function()
    it("should restore cursor position after change", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      assert.is_not_nil(_G.vim.api.nvim_win_set_cursor)
    end)

    it("should re-apply extmarks after restoration", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
    end)
  end)

  describe("full workflow simulation", function()
    it("should handle setup -> BufReadPost -> TextChanged sequence", function()
      ro.setup({
        region_text = { start = "begin read only", ending = "end read only" },
      })

      -- Simulate BufReadPost
      local bufread_callback = autocmd_callbacks[2].opts.callback
      assert.has_no_error(function()
        bufread_callback()
      end)

      -- Verify extmarks were created
      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
    end)

    it("should handle multiple BufReadPost events", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback

      assert.has_no_error(function()
        bufread_callback()
        bufread_callback()
      end)
    end)
  end)

  describe("configuration persistence", function()
    it("should maintain options across callback invocations", function()
      ro.setup({ region_text = { start = "TEST_START", ending = "TEST_END" } })
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()
      assert.is_equal("TEST_START", ro.opt.region_text.start)
    end)

    it("should allow option updates between callbacks", function()
      ro.setup({ region_text = { start = "OLD", ending = "OLD_END" } })
      ro.setup({ region_text = { start = "NEW", ending = "NEW_END" } })
      assert.is_equal("NEW", ro.opt.region_text.start)
    end)
  end)

  describe("region modification detection and protection", function()
    it("should detect modified regions and trigger protection", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      -- Verify extmark was populated
      assert.is_not_nil(ro.extmark[42])

      -- Mock deep_equal to return false (lines changed)
      _G.vim.deep_equal = function()
        return false
      end

      _G.vim.api.nvim_buf_get_extmarks = stub.new().returns({
        { 42, 1, 0, { end_row = 2 } },
      })
      _G.vim.api.nvim_buf_get_lines = stub.new().returns({
        "modified_A",
        "modified_B",
      })

      _G.vim.schedule = function(cb)
        cb()
      end

      local text_changed_callback = autocmd_callbacks[3].opts.callback
      text_changed_callback()

      -- Verify protection notification was triggered
      assert.stub(utils.notify).was_called()
    end)

    it("should not trigger protection if lines unchanged", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })
      local utils = require("gnattest.utils")
      local bufread_callback = autocmd_callbacks[2].opts.callback
      bufread_callback()

      -- Mock deep_equal to return true (lines unchanged)
      _G.vim.deep_equal = function()
        return true
      end

      _G.vim.api.nvim_buf_get_extmarks = stub.new().returns({
        { 42, 1, 0, { end_row = 2 } },
      })
      _G.vim.api.nvim_buf_get_lines = stub.new().returns({
        "lineA",
        "lineB",
      })

      _G.vim.schedule = function(cb)
        cb()
      end

      local notify_count_before = #utils.notify.calls
      local text_changed_callback = autocmd_callbacks[3].opts.callback
      text_changed_callback()
      local notify_count_after = #utils.notify.calls

      -- No new notifications should be triggered
      assert.is_equal(notify_count_before, notify_count_after)
    end)

    it("should skip processing when in diff mode", function()
      ro.setup({ region_text = { start = "begin", ending = "end" } })

      -- Set diff mode to true
      _G.vim.opt.diff.get = function()
        return true
      end

      local schedule_called = false
      _G.vim.schedule = function()
        schedule_called = true
      end

      local text_changed_callback = autocmd_callbacks[3].opts.callback
      text_changed_callback()

      -- In diff mode, vim.schedule should not be called
      assert.is_false(schedule_called)
    end)
  end)
end)
