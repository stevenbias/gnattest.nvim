local helpers = require("spec.helpers.common")

describe("gnattest.config", function()
  local config

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
      assert.equals("begin read only", opts.read_only.region_text.start)
      assert.equals("end read only", opts.read_only.region_text.ending)
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
      assert.equals("begin read only", opts.read_only.region_text.start) -- default preserved
    end)

    it("should handle nested region_text config", function()
      config.set({
        read_only = { region_text = { start = "LOCK", ending = "UNLOCK" } },
      })
      local opts = config.get()
      assert.equals("LOCK", opts.read_only.region_text.start)
      assert.equals("UNLOCK", opts.read_only.region_text.ending)
    end)

    it("should handle nil opts (use defaults)", function()
      config.set(nil)
      local opts = config.get()
      assert.equals(3, opts.highlight.percent)
      assert.is_true(opts.read_only.enabled)
    end)

    it("should handle empty table (use defaults)", function()
      config.set({})
      local opts = config.get()
      assert.equals(3, opts.highlight.percent)
      assert.is_true(opts.read_only.enabled)
    end)
  end)

  describe("set() with multiple calls", function()
    it("should allow updating config multiple times", function()
      config.set({ highlight = { percent = 5 } })
      assert.equals(5, config.get().highlight.percent)

      config.set({ highlight = { percent = 10 } })
      assert.equals(10, config.get().highlight.percent)
    end)

    it("should reset to defaults on each set()", function()
      config.set({ highlight = { percent = 10 } })
      config.set({ read_only = { enabled = false } })
      local opts = config.get()
      -- First config (highlight) should be reset to default
      assert.equals(3, opts.highlight.percent)
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
      local opts = config.get()
      assert.equals(3, opts.highlight.percent) -- still defaults
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
      local opts = config.get()
      assert.equals(3, opts.highlight.percent) -- still defaults, not 5
    end)
  end)

  describe("validation - type checking", function()
    it("should reject non-string region_text.start", function()
      local utils = require("gnattest.utils")
      config.set({
        read_only = { region_text = { start = 123, ending = "end" } },
      })

      assert
        .stub(utils.notify)
        .was_called_with("region_text.start and ending must be strings", vim.log.levels.ERROR)
    end)

    it("should reject non-string region_text.ending", function()
      local utils = require("gnattest.utils")
      config.set({
        read_only = { region_text = { start = "start", ending = true } },
      })

      assert
        .stub(utils.notify)
        .was_called_with("region_text.start and ending must be strings", vim.log.levels.ERROR)
    end)

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
        read_only = { region_text = { start = "START", ending = "END" } },
      })

      assert.stub(utils.notify).was_not_called()
      assert.equals(10, config.get().highlight.percent)
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
