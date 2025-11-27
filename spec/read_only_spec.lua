local stub = require("luassert.stub")

describe("gnattest.read_only", function()
  local ro

  before_each(function()
    _G.vim.api = {
      nvim_create_namespace = function()
        return "test"
      end,
      nvim_create_augroup = function()
        return "autest"
      end,
      nvim_create_autocmd = stub.new(),
      nvim_buf_set_extmark = function()
        return math.random(1, 100)
      end,
      nvim_get_current_buf = function()
        return 0
      end,
      nvim_buf_get_lines = function()
        return { "a", "b" }
      end,
      nvim_buf_get_extmarks = function()
        return {}
      end,
      nvim_buf_set_lines = stub.new(),
      nvim__get_runtime = function()
        return {}
      end,
      nvim_win_set_cursor = stub.new(),
    }
    _G.vim.fn = {
      getpos = function()
        return { 0, 1, 1 }
      end,
    }
    _G.vim.opt = {
      diff = {
        get = function()
          return false
        end,
      },
    }
    _G.vim.cmd = stub.new()
    _G.vim.schedule = function(fn)
      fn()
    end
    _G.vim.deep_equal = function(a, b)
      return vim.deep_equal(a, b)
    end
    package.preload["gnattest.utils"] = function()
      return {
        get_bufid = function()
          return 1
        end,
        get_lines = function()
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
end)
