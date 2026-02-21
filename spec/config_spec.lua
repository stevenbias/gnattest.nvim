local helpers = require("spec.helpers.common")

describe("gnattest.config", function()
  local config

  local function assert_defaults(opts)
    assert.equals(3, opts.highlight.percent)
    assert.is_true(opts.read_only.enabled)
  end

  before_each(function()
    helpers.mock_utils()

    package.loaded["gnattest.config"] = nil
    config = require("gnattest.config")
  end)

  after_each(function()
    package.loaded["gnattest.config"] = nil
    helpers.cleanup_packages()
  end)

  describe("default configuration", function()
    it("should have default highlight config", function()
      local opts = config.get()
      assert.is_not_nil(opts.highlight)
      assert.equals(3, opts.highlight.percent)
    end)

    it("should have default read_only config", function()
      local opts = config.get()
      assert.is_not_nil(opts.read_only)
      assert.is_true(opts.read_only.enabled)
    end)
  end)

  describe("set() with valid config", function()
    it("should merge user config with defaults", function()
      config.set({ highlight = { percent = 5 } })
      local opts = config.get()
      assert.equals(5, opts.highlight.percent)
      assert.is_true(opts.read_only.enabled) -- defaults preserved
    end)

    it("should handle partial read_only config", function()
      config.set({ read_only = { enabled = false } })
      local opts = config.get()
      assert.is_false(opts.read_only.enabled)
    end)

    it("should handle nil opts (use defaults)", function()
      config.set(nil)
      assert_defaults(config.get())
    end)

    it("should handle empty table (use defaults)", function()
      config.set({})
      assert_defaults(config.get())
    end)
  end)

  describe("setup() with valid config", function()
    it("should reset to defaults and apply options", function()
      config.set({ highlight = { percent = 10 } })
      config.setup({ read_only = { enabled = false } })
      local opts = config.get()
      assert.equals(3, opts.highlight.percent)
      assert.is_false(opts.read_only.enabled)
    end)

    it("should not update when config is invalid", function()
      config.set({ highlight = { percent = 10 } })
      local utils = require("gnattest.utils")
      config.setup({ highlight = { percent = "bad" } })
      assert
        .stub(utils.notify)
        .was_called_with("highlight.percent must be a number", vim.log.levels.ERROR)
      assert.equals(10, config.get().highlight.percent)
    end)
  end)

  describe("set() with multiple calls", function()
    it("should allow updating config multiple times", function()
      config.set({ highlight = { percent = 5 } })
      assert.equals(5, config.get().highlight.percent)

      config.set({ highlight = { percent = 10 } })
      assert.equals(10, config.get().highlight.percent)
    end)

    it("should merge with existing config on each set()", function()
      config.set({ highlight = { percent = 10 } })
      config.set({ read_only = { enabled = false } })
      local opts = config.get()
      -- First config (highlight) should be preserved
      assert.equals(10, opts.highlight.percent)
      -- Second config should be applied
      assert.is_false(opts.read_only.enabled)
    end)
  end)

  describe("validation - unknown fields", function()
    it("should reject unknown top-level field", function()
      local utils = require("gnattest.utils")
      config.set({ unknown_field = "value" })

      assert
        .stub(utils.notify)
        .was_called_with("Unknown config field: unknown_field", vim.log.levels.ERROR)

      -- Config should not be updated
      assert_defaults(config.get())
    end)

    it("should reject multiple unknown fields", function()
      local utils = require("gnattest.utils")
      config.set({ field1 = "a", field2 = "b" })

      -- Should notify about at least one unknown field
      assert.stub(utils.notify).was_called()
    end)

    it("should reject config with mix of valid and invalid fields", function()
      local utils = require("gnattest.utils")
      config.set({ highlight = { percent = 5 }, invalid = "bad" })

      -- Should reject entire config
      assert.stub(utils.notify).was_called()
      assert_defaults(config.get())
    end)
  end)

  describe("validation - type checking", function()
    it("should reject non-number highlight.percent", function()
      local utils = require("gnattest.utils")
      config.set({ highlight = { percent = "not a number" } })

      assert
        .stub(utils.notify)
        .was_called_with("highlight.percent must be a number", vim.log.levels.ERROR)
    end)

    it("should accept valid types", function()
      local utils = require("gnattest.utils")
      config.set({
        highlight = { percent = 10 },
        read_only = { enabled = false },
      })

      assert.stub(utils.notify).was_not_called()
      assert.equals(10, config.get().highlight.percent)
      assert.is_false(config.get().read_only.enabled)
    end)
  end)

  describe("get()", function()
    it("should return current config", function()
      local opts = config.get()
      assert.is_table(opts)
      assert.is_not_nil(opts.highlight)
      assert.is_not_nil(opts.read_only)
    end)

    it("should return updated config after set()", function()
      config.set({ highlight = { percent = 7 } })
      local opts = config.get()
      assert.equals(7, opts.highlight.percent)
    end)
  end)
end)
