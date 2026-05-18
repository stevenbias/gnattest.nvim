local stub_new = require("luassert.stub").new
local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.init", function()
  local gnattest_init
  local config_mock
  local read_only_mock
  local ada_ls_mock
  local captured_callback

  local function make_autocmd_stub()
    local autocmd_stubbed = stub.new()
    autocmd_stubbed.invokes = function(self, fn)
      self._fn = fn
      return self
    end
    local mt = {
      __call = function(self, event, opts)
        captured_callback = opts and opts.callback
        if self._fn then
          self._fn(event, opts)
        end
      end,
    }
    setmetatable(autocmd_stubbed, mt)
    return autocmd_stubbed
  end

  before_each(function()
    captured_callback = nil

    common.setup_vim_globals(
      {
        nvim__get_runtime = function()
          return {}
        end,
        nvim_create_autocmd = make_autocmd_stub(),
        nvim_create_augroup = function()
          return 1
        end,
      },
      nil,
      {
        lsp = {
          get_clients = stub_new(),
          get_client_by_id = stub_new().returns(nil),
        },
        log = { levels = { WARN = 3, ERROR = 4 } },
        defer_fn = function(cb)
          cb()
        end,
      }
    )

    config_mock = { setup = stub_new() }
    package.preload["gnattest.config"] = function()
      return config_mock
    end

    read_only_mock = { setup = stub_new() }
    package.preload["gnattest.read_only"] = function()
      return read_only_mock
    end

    ada_ls_mock = { setup = stub_new() }
    package.preload["gnattest.ada_ls"] = function()
      return ada_ls_mock
    end

    package.loaded["gnattest.init"] = nil
    gnattest_init = require("gnattest.init")
  end)

  after_each(function()
    package.preload["gnattest.config"] = nil
    package.preload["gnattest.read_only"] = nil
    package.preload["gnattest.ada_ls"] = nil
    package.loaded["gnattest.config"] = nil
    package.loaded["gnattest.read_only"] = nil
    package.loaded["gnattest.ada_ls"] = nil
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

    it("should call read_only.setup()", function()
      gnattest_init.setup()
      assert.stub(read_only_mock.setup).was_called()
    end)

    it("should create LspAttach autocmd for ada files", function()
      gnattest_init.setup()
      assert.is_not_nil(captured_callback)
    end)
  end)

  describe("LspAttach callback", function()
    it("skips when client is nil", function()
      gnattest_init.setup()
      _G.vim.lsp.get_client_by_id = stub_new().returns(nil)

      captured_callback({ data = { client_id = 1 } })

      assert.stub(ada_ls_mock.setup).was_not_called()
    end)

    it("skips when client is not ada_ls", function()
      gnattest_init.setup()
      local non_ada = { name = "rust_analyzer", id = 1 }
      _G.vim.lsp.get_client_by_id = stub_new().returns(non_ada)

      captured_callback({ data = { client_id = 1 } })

      assert.stub(ada_ls_mock.setup).was_not_called()
    end)

    it("skips when ada_ls module is not installed", function()
      gnattest_init.setup()
      local utils = require("gnattest.utils")
      utils.try_require = function()
        return false
      end
      local ada = { name = "ada_ls", id = 1 }
      _G.vim.lsp.get_client_by_id = stub_new().returns(ada)

      captured_callback({ data = { client_id = 1 } })

      assert.stub(ada_ls_mock.setup).was_not_called()
    end)

    it(
      "calls ada_ls.setup() when ada_ls client and module available",
      function()
        gnattest_init.setup()
        local utils = require("gnattest.utils")
        utils.try_require = function()
          return true
        end
        local ada = { name = "ada_ls", id = 1 }
        _G.vim.lsp.get_client_by_id = stub_new().returns(ada)

        captured_callback({ data = { client_id = 1 } })

        assert.stub(ada_ls_mock.setup).was_called()
      end
    )
  end)
end)
