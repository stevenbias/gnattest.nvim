local stub_new = require("luassert.stub").new

describe("gnattest.init", function()
  local gnattest_init
  local config_mock

  before_each(function()
    -- Mock config module
    config_mock = {
      setup = stub_new(),
    }
    package.preload["gnattest.config"] = function()
      return config_mock
    end

    package.loaded["gnattest.init"] = nil
    gnattest_init = require("gnattest.init")
  end)

  after_each(function()
    package.preload["gnattest.config"] = nil
    package.loaded["gnattest.config"] = nil
    package.loaded["gnattest.init"] = nil
  end)

  describe("setup()", function()
    it("should delegate to config.setup() with nil", function()
      gnattest_init.setup()
      assert.stub(config_mock.setup).was_called_with(nil)
    end)

    it("should delegate to config.setup() with empty table", function()
      gnattest_init.setup({})
      assert.stub(config_mock.setup).was_called_with({})
    end)

    it("should delegate to config.setup() with options", function()
      local opts = { highlight = { percent = 5 } }
      gnattest_init.setup(opts)
      assert.stub(config_mock.setup).was_called_with(opts)
    end)

    it("should pass through any options to config", function()
      local opts = { read_only = { enabled = false } }
      gnattest_init.setup(opts)
      assert.stub(config_mock.setup).was_called_with(opts)
    end)
  end)
end)
