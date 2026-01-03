local stub = require("luassert.stub")
local helpers = require("spec.helpers.common")

describe("gnattest.highlight", function()
  local highlight

  -- Helper function to reload highlight module with fresh config
  -- Used when tests need to modify vim API behavior and reload the module
  local function reload_highlight()
    package.loaded["gnattest.highlight"] = nil
    highlight = require("gnattest.highlight")
    highlight.setup()
  end

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

    -- Mock config module
    package.preload["gnattest.config"] = function()
      return {
        get = function()
          return {
            highlight = { percent = 3 },
          }
        end,
      }
    end

    reload_highlight()
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

  it("should use default color when nvim_get_hl returns no bg", function()
    _G.vim.api.nvim_get_hl = function(_, _)
      return {}
    end
    reload_highlight()

    highlight.set_highlight(123, "MyHighlight")

    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#303030", force = true })
  end)

  it("should use default color when nvim_get_hl returns nil", function()
    _G.vim.api.nvim_get_hl = function(_, _)
      return nil
    end
    reload_highlight()

    highlight.set_highlight(123, "MyHighlight")

    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#303030", force = true })
  end)

  it("should lighten color for light background", function()
    _G.vim.o.background = "light"
    reload_highlight()

    highlight.set_highlight(123, "MyHighlight")

    -- With 0x101010 and -3% adjustment for light background
    -- 0x101010 = rgb(16, 16, 16)
    -- -3% of 255 = -7.65 = -8 (floor of -7.65)
    -- 16 - 8 = 8 = 0x08
    -- Result should be #080808
    assert
      .stub(_G.vim.api.nvim_set_hl)
      .was_called_with(123, "MyHighlight", { bg = "#080808", force = true })
  end)

  if helpers.should_test_private_functions() then
    describe("private functions", function()
      it("_hex_to_rgb converts hex color to RGB table", function()
        local rgb = highlight._hex_to_rgb("#ff0000")
        assert.same({ r = 255, g = 0, b = 0 }, rgb)
      end)

      local hex_to_rgb_cases = {
        { hex = "#000000", expected = { r = 0, g = 0, b = 0 } },
        { hex = "#ffffff", expected = { r = 255, g = 255, b = 255 } },
        { hex = "#303030", expected = { r = 48, g = 48, b = 48 } },
        { hex = "#abcdef", expected = { r = 171, g = 205, b = 239 } },
      }

      for _, case in ipairs(hex_to_rgb_cases) do
        it("_hex_to_rgb handles " .. case.hex .. " correctly", function()
          assert.same(case.expected, highlight._hex_to_rgb(case.hex))
        end)
      end

      it("_rgb_to_hex converts RGB table to hex string", function()
        local hex = highlight._rgb_to_hex({ r = 255, g = 0, b = 0 })
        assert.equals("#ff0000", hex)
      end)

      local rgb_to_hex_cases = {
        { rgb = { r = 0, g = 0, b = 0 }, expected = "#000000" },
        { rgb = { r = 255, g = 255, b = 255 }, expected = "#ffffff" },
        { rgb = { r = 48, g = 48, b = 48 }, expected = "#303030" },
        { rgb = { r = 171, g = 205, b = 239 }, expected = "#abcdef" },
      }

      for _, case in ipairs(rgb_to_hex_cases) do
        it("_rgb_to_hex handles " .. case.expected .. " correctly", function()
          assert.equals(case.expected, highlight._rgb_to_hex(case.rgb))
        end)
      end

      it("_rgb_to_hex returns #000000 for nil input", function()
        assert.equals("#000000", highlight._rgb_to_hex(nil))
      end)

      it("_rgb_to_hex returns #000000 for incomplete RGB", function()
        assert.equals("#000000", highlight._rgb_to_hex({ r = 255 }))
        assert.equals("#000000", highlight._rgb_to_hex({ r = 255, g = 0 }))
        assert.equals("#000000", highlight._rgb_to_hex({ g = 0, b = 0 }))
      end)

      it("_modify_color lightens color by positive percent", function()
        local result = highlight._modify_color("#101010", 10)
        -- 0x10 = 16, 10% of 255 = 25.5 -> 25
        -- 16 + 25 = 41 = 0x29
        assert.equals("#292929", result)
      end)

      it("_modify_color darkens color by negative percent", function()
        local result = highlight._modify_color("#505050", -10)
        -- 0x50 = 80, 10% of 255 = 25.5 -> 25 (floor)
        -- 80 + (-25) = 55... wait, floor(-25.5) = -26
        -- 80 + (-26) = 54 = 0x36
        assert.equals("#363636", result)
      end)

      it("_modify_color clamps values to 0-255 range", function()
        -- Test clamping to 255
        local result_max = highlight._modify_color("#ff0000", 50)
        -- ff + (255 * 0.5) = 255 + 127 = 382, clamped to 255 = 0xff
        -- 00 + 127 = 127 = 0x7f
        assert.equals("#ff7f7f", result_max)

        -- Test clamping to 0
        local result_min = highlight._modify_color("#101010", -50)
        -- 16 - 127 = -111, clamped to 0
        assert.equals("#000000", result_min)
      end)

      it("_get_hl returns hex color from Normal highlight", function()
        local hl = highlight._get_hl()
        assert.equals("#101010", hl)
      end)

      it("_get_hl returns nil when no background color", function()
        _G.vim.api.nvim_get_hl = function(_, _)
          return {}
        end
        reload_highlight()
        local hl = highlight._get_hl()
        assert.is_nil(hl)
      end)

      it("_get_hl returns nil when nvim_get_hl returns nil", function()
        _G.vim.api.nvim_get_hl = function(_, _)
          return nil
        end
        reload_highlight()
        local hl = highlight._get_hl()
        assert.is_nil(hl)
      end)
    end)
  end
end)
