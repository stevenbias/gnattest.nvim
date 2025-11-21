local stub = require("luassert.stub")

describe("gnattest.highlight", function()
  local highlight

  before_each(function()
    -- Stub vim.o for background
    _G.vim.api = {
      nvim_get_hl = function(_, _)
        return { bg = 0x101010 }
      end,
      nvim_set_hl = stub.new(),
      nvim_set_hl_ns = stub.new(),
      nvim__get_runtime = function()
        return {}
      end,
    }
    _G.vim.o = {
      background = "dark",
    }
    highlight = require("gnattest.highlight")
  end)

  after_each(function()
    package.loaded["gnattest.highlight"] = nil
  end)

  it("sets hl_group via set_highlight", function()
    highlight.set_highlight(123, "MyHighlight")
    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#171717", force = true })
    assert.stub(_G.vim.api.nvim_set_hl_ns).was_called_with(123)
  end)

  it("should store opts on setup", function()
    highlight.setup({ foo = "bar" })
    assert.same({ foo = "bar" }, highlight.opt)
  end)
end)
