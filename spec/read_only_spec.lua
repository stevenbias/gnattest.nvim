local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.read_only", function()
  local ro
  local autocmd_callbacks = {}

  local function mock_config(read_only_opts)
    package.loaded["gnattest.config"] = nil
    local config_mock = {
      set = stub.new(),
    }
    package.preload["gnattest.config"] = function()
      return {
        get = function()
          return { read_only = read_only_opts }
        end,
        set = config_mock.set,
      }
    end
    return config_mock
  end

  local function setup_default_config()
    mock_config({
      enabled = true,
      region_text = {
        start = "begin read only",
        ending = "end read only",
      },
    })
  end

  local function get_callback(index)
    return autocmd_callbacks[index].opts.callback
  end

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
      nvim_buf_clear_namespace = stub.new(),
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
    _G.vim.deep_equal = function()
      return true
    end

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
      return {
        set_highlight = stub.new(),
        setup = function() end,
      }
    end

    setup_default_config()

    ro = require("gnattest.read_only")
  end)

  after_each(function()
    common.cleanup_packages()
    package.preload["gnattest.highlight"] = nil
    package.loaded["gnattest.config"] = nil
    package.preload["gnattest.config"] = nil
  end)

  describe("setup", function()
    it("loads config and registers autocmds", function()
      ro.setup()

      assert.is_table(ro.opt)
      assert.is_true(ro.opt.enabled)
      assert.equals("begin read only", ro.opt.region_text.start)
      assert.equals("end read only", ro.opt.region_text.ending)

      assert.equals(5, #autocmd_callbacks)
      assert.equals("ColorScheme", autocmd_callbacks[1].event)

      assert.is_table(autocmd_callbacks[2].event)
      assert.equals("BufReadPost", autocmd_callbacks[2].event[1])
      assert.equals("BufWinEnter", autocmd_callbacks[2].event[2])
      assert.equals("BufEnter", autocmd_callbacks[2].event[3])

      assert.is_table(autocmd_callbacks[3].event)
      assert.equals("TextChanged", autocmd_callbacks[3].event[1])
      assert.equals("TextChangedI", autocmd_callbacks[3].event[2])

      assert.equals("User", autocmd_callbacks[4].event)
      assert.equals("ConformFormatPre", autocmd_callbacks[4].opts.pattern)
      assert.equals("User", autocmd_callbacks[5].event)
      assert.equals("ConformFormatPost", autocmd_callbacks[5].opts.pattern)

      for _, callback in ipairs(autocmd_callbacks) do
        assert.equals("autest", callback.opts.group)
      end

      assert.is_table(autocmd_callbacks[2].opts.pattern)
      assert.is_table(autocmd_callbacks[3].opts.pattern)
    end)

    it("skips setup when read_only is disabled", function()
      mock_config({
        enabled = false,
        region_text = {
          start = "begin read only",
          ending = "end read only",
        },
      })

      ro.setup()

      assert.equals(0, #autocmd_callbacks)
    end)

    it("updates options on subsequent setups", function()
      ro.setup()
      mock_config({
        enabled = true,
        region_text = { start = "start", ending = "finish" },
      })

      ro.setup()

      assert.equals("start", ro.opt.region_text.start)
      assert.equals("finish", ro.opt.region_text.ending)
    end)

    it("ColorScheme callback applies highlight", function()
      ro.setup()
      local hl = require("gnattest.highlight")
      local colorscheme_callback = get_callback(1)

      colorscheme_callback()

      assert.stub(hl.set_highlight).was_called()
    end)
  end)

  describe("callbacks", function()
    before_each(function()
      ro.setup()
    end)

    it("BufReadPost refreshes extmarks", function()
      local bufread_callback = get_callback(2)

      bufread_callback()

      assert.stub(_G.vim.api.nvim_buf_set_extmark).was_called()
      assert.is_not_nil(ro.backup)
    end)

    it("TextChanged protects modified lines and skips diff mode", function()
      local utils = require("gnattest.utils")
      local bufread_callback = get_callback(2)
      bufread_callback()

      _G.vim.opt.diff.get = function()
        return false
      end
      _G.vim.deep_equal = function()
        return false
      end
      _G.vim.api.nvim_buf_get_extmarks = stub.new().returns({
        { 42, 1, 0, { end_row = 2 } },
      })
      _G.vim.api.nvim_buf_get_lines =
        stub.new().returns({ "modified_A", "modified_B" })

      local text_changed_callback = get_callback(3)
      text_changed_callback()

      assert.stub(utils.notify).was_called()

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

    it("uses protect_flag to refresh only once", function()
      local bufread_callback = get_callback(2)
      bufread_callback()

      _G.vim.opt.diff.get = function()
        return false
      end
      _G.vim.deep_equal = function()
        return false
      end
      local get_extmarks_spy = stub(_G.vim.api, "nvim_buf_get_extmarks")
      get_extmarks_spy.returns({ { 42, 1, 0, { end_row = 2 } } })

      local text_changed_callback = get_callback(3)
      text_changed_callback()
      local call_count = #get_extmarks_spy.calls

      text_changed_callback()

      assert.equals(call_count, #get_extmarks_spy.calls)
    end)

    it("returns early when diff mode enabled", function()
      ro.setup()
      _G.vim.opt.diff.get = function()
        return true
      end

      get_callback(3)()
    end)
  end)

  describe("conform workaround", function()
    it("skips conform workaround when read_only is disabled", function()
      autocmd_callbacks = {}
      local config = require("gnattest.config")
      local calls = 0
      config.get = function()
        calls = calls + 1
        if calls == 1 then
          return { read_only = { enabled = true } }
        end
        return { read_only = { enabled = false } }
      end

      ro.setup()

      assert.equals(3, #autocmd_callbacks)
    end)

    it("disables read_only during ConformFormatPre", function()
      ro.setup()
      local pre_callback = get_callback(4)

      pre_callback()

      assert.is_false(ro.opt.enabled)
    end)

    it("re-enables read_only during ConformFormatPost", function()
      ro.setup()
      local pre_callback = get_callback(4)
      local post_callback = get_callback(5)
      local schedule_spy = stub.new().invokes(function(cb)
        cb()
      end)
      _G.vim.schedule = schedule_spy

      pre_callback()
      post_callback()

      assert.is_true(ro.opt.enabled)
      assert.stub(schedule_spy).was_called()
    end)

    it("skips ConformFormatPost when read_only disabled", function()
      ro.setup()
      local pre_callback = get_callback(4)
      local post_callback = get_callback(5)
      local schedule_spy = stub.new()
      _G.vim.schedule = schedule_spy

      local config = require("gnattest.config")
      config.get = function()
        return { read_only = { enabled = false } }
      end

      pre_callback()
      post_callback()

      assert.is_false(ro.opt.enabled)
      assert.stub(schedule_spy).was_not_called()
    end)
  end)

  describe("refresh and reset", function()
    it("refresh clears state when read_only is disabled", function()
      ro.setup()
      ro.extmark[42] = { lines = { "lineA" } }

      local config = require("gnattest.config")
      config.get = function()
        return { read_only = { enabled = false } }
      end

      local bufread_callback = get_callback(2)
      bufread_callback()

      assert.stub(_G.vim.api.nvim_buf_clear_namespace).was_called()
      assert.is_nil(ro.backup)
      assert.is_true(next(ro.extmark) == nil)
    end)

    it("refresh clears namespace with end_row -1", function()
      ro.setup()
      ro.extmark[42] = { lines = { "lineA" } }
      local config = require("gnattest.config")
      config.get = function()
        return { read_only = { enabled = false } }
      end

      local bufread_callback = get_callback(2)
      bufread_callback()

      assert
        .stub(_G.vim.api.nvim_buf_clear_namespace)
        .was_called_with(1, ro.namespace, 0, -1)
    end)

    it("reset clears and reinitializes state", function()
      ro.setup()
      ro.extmark[1] = { lines = { "lineA" } }

      ro.reset()

      assert.stub(_G.vim.api.nvim_buf_clear_namespace).was_called()
      assert.is_table(ro.extmark)
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

      it("_get_regions creates backup and invokes callback", function()
        ro.setup()
        local bufread_callback = get_callback(2)
        bufread_callback()

        ro.backup = nil
        local cb_calls = {}

        ro._get_regions(function(start_line, end_line, index)
          table.insert(cb_calls, { start_line, end_line, index })
        end)

        assert.is_not_nil(ro.backup)
        assert.is_equal(1, #cb_calls)
        assert.is_equal(1, cb_calls[1][1])
        assert.is_equal(2, cb_calls[1][2])
        assert.is_equal(1, cb_calls[1][3])
      end)

      it("_set_extmark updates an existing mark id", function()
        ro._set_extmark(1, 2, 0)
        ro._set_extmark(1, 2, 99)

        local last_call =
          _G.vim.api.nvim_buf_set_extmark.calls[#_G.vim.api.nvim_buf_set_extmark.calls]
        assert.is_table(last_call)
        assert.is_table(last_call.vals)
        assert.is_table(last_call.vals[5])
        assert.is_equal(99, last_call.vals[5].id)
      end)

      it("_fix_ro_regions restores modified lines", function()
        ro.setup()
        local bufread_callback = get_callback(2)
        bufread_callback()

        _G.vim.opt.diff.get = function()
          return false
        end
        _G.vim.deep_equal = function()
          return false
        end
        _G.vim.api.nvim_buf_get_extmarks = stub.new().returns({
          { 42, 1, 0, { end_row = 2 } },
        })
        _G.vim.api.nvim_buf_get_lines = stub.new().returns({ "changed" })

        ro._fix_ro_regions()

        assert.stub(_G.vim.api.nvim_buf_set_lines).was_called()
        assert.stub(_G.vim.api.nvim_win_set_cursor).was_called()
        assert.stub(_G.vim.cmd).was_called_with([[stopinsert]])
      end)

      it("_fix_ro_regions clears state when read_only disabled", function()
        ro.setup()
        local bufread_callback = get_callback(2)
        bufread_callback()

        local config = require("gnattest.config")
        config.get = function()
          return { read_only = { enabled = false } }
        end

        ro._fix_ro_regions()

        assert.stub(_G.vim.api.nvim_buf_clear_namespace).was_called()
      end)

      it(
        "_fix_ro_regions calls get_extmarks with details and overlap",
        function()
          ro.setup()
          local bufread_callback = get_callback(2)
          bufread_callback()

          _G.vim.opt.diff.get = function()
            return false
          end

          local get_extmarks_args = nil
          _G.vim.api.nvim_buf_get_extmarks = stub.new().invokes(function(...)
            get_extmarks_args = { ... }
            return {}
          end)

          ro._fix_ro_regions()

          assert.stub(_G.vim.api.nvim_buf_get_extmarks).was_called()
          assert.is_not_nil(get_extmarks_args)
          assert.is_table(get_extmarks_args[5])
          assert.is_true(get_extmarks_args[5].details)
          assert.is_true(get_extmarks_args[5].overlap)
        end
      )
    end)
  end
end)
