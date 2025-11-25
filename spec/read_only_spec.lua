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
    _G.vim.schedule = function(fn)
      fn()
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
end)
