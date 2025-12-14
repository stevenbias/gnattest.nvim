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
      .was_called_with(123, "MyHighlight", { bg = "#000000", force = true })
    assert.stub(_G.vim.api.nvim_set_hl_ns).was_called_with(123)
  end)

  it("should store opts on setup", function()
    highlight.setup({ foo = "bar" })
    assert.same({ foo = "bar" }, highlight.opt)
  end)

  it("should use default color when nvim_get_hl returns no bg", function()
    _G.vim.api.nvim_get_hl = function(_, _)
      return {}
    end
    highlight = require("gnattest.highlight")

    highlight.set_highlight(123, "MyHighlight")

    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#303030", force = true })
  end)

  it("should use default color when nvim_get_hl returns nil", function()
    _G.vim.api.nvim_get_hl = function(_, _)
      return nil
    end
    highlight = require("gnattest.highlight")

    highlight.set_highlight(123, "MyHighlight")

    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#303030", force = true })
  end)

  it("should lighten color for light background", function()
    _G.vim.o.background = "light"
    highlight = require("gnattest.highlight")

    highlight.set_highlight(123, "MyHighlight")

    -- With 0x101010 and -3% adjustment for light background
    -- 0x101010 = rgb(16, 16, 16)
    -- -3% of 255 = -7.65 = -8 (floor of -7.65)
    -- 16 - 8 = 8 = 0x08
    -- Result should be #080808
    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#000000", force = true })
  end)
end)
