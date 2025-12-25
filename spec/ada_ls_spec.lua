local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.ada_ls", function()
  local ada_ls
  local autocmd_callbacks = {}

  before_each(function()
    autocmd_callbacks = {}

    -- Extend existing vim with necessary mocks
    _G.vim.lsp = {
      get_clients = stub.new().returns({}),
      get_client_by_id = stub.new().returns(nil),
    }

    _G.vim.api = _G.vim.api or {}
    _G.vim.api.nvim_create_autocmd = stub.new().invokes(function(event, opts)
      table.insert(autocmd_callbacks, { event = event, opts = opts })
    end)

    _G.vim.log = _G.vim.log
      or {
        levels = {
          WARN = 3,
        },
      }

    -- Mock utils module
    common.mock_utils({
      get_bufdir = function()
        return "/home/user/project/gnattest/harness"
      end,
    })

    -- Reload ada_ls to get fresh instance with mocked deps
    package.loaded["gnattest.ada_ls"] = nil
    ada_ls = require("gnattest.ada_ls")
  end)

  after_each(function()
    common.cleanup_packages()
    package.loaded["gnattest.ada_ls"] = nil
  end)

  describe("get_ada_ls()", function()
    it("should return nil if clients is nil", function()
      _G.vim.lsp.get_clients = stub.new().returns(nil)

      local result = ada_ls.get_ada_ls()

      assert.is_nil(result)
    end)

    it("should return nil if no clients are active", function()
      _G.vim.lsp.get_clients = stub.new().returns({})

      local result = ada_ls.get_ada_ls()

      assert.is_nil(result)
    end)

    it("should notify with WARN level when no clients found", function()
      _G.vim.lsp.get_clients = stub.new().returns({})
      local utils = require("gnattest.utils")

      ada_ls.get_ada_ls()

      assert.stub(utils.notify).was_called()
      local call_args = utils.notify.calls[1]
      assert.is_equal("Ada LSP client not found", call_args.vals[1])
      assert.is_equal(_G.vim.log.levels.WARN, call_args.vals[2])
    end)

    it("should return first client when clients exist", function()
      local mock_client = { name = "ada", id = 1 }
      _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

      local result = ada_ls.get_ada_ls()

      assert.is_equal(mock_client, result)
    end)

    it("should return first client from multiple clients", function()
      local client1 = { name = "ada", id = 1 }
      local client2 = { name = "ada", id = 2 }
      _G.vim.lsp.get_clients = stub.new().returns({ client1, client2 })

      local result = ada_ls.get_ada_ls()

      assert.is_equal(client1, result)
    end)

    it("should query LSP with ada name filter", function()
      _G.vim.lsp.get_clients = stub.new().returns({})

      ada_ls.get_ada_ls()

      assert.stub(_G.vim.lsp.get_clients).was_called_with({ name = "ada" })
    end)
  end)

  describe("setup()", function()
    it("should create LspAttach autocmd", function()
      ada_ls.setup()

      assert.stub(_G.vim.api.nvim_create_autocmd).was_called()
      local first_call = autocmd_callbacks[1]
      assert.is_equal("LspAttach", first_call.event)
    end)

    it("should set pattern for gnattest Ada files", function()
      ada_ls.setup()

      local first_call = autocmd_callbacks[1]
      assert.is_table(first_call.opts.pattern)
      assert.is_equal(1, #first_call.opts.pattern)
      assert.is_equal("**/gnattest/*.ad[bs]", first_call.opts.pattern[1])
    end)

    it("should create callback function", function()
      ada_ls.setup()

      local first_call = autocmd_callbacks[1]
      assert.is_not_nil(first_call.opts.callback)
      assert.is_function(first_call.opts.callback)
    end)

    describe("LspAttach callback", function()
      it("should handle Ada client found", function()
        ada_ls.setup()
        local callback = autocmd_callbacks[1].opts.callback

        local mock_client = {
          name = "ada",
          notify = stub.new(),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)

        local event = {
          data = { client_id = 123 },
        }

        callback(event)

        assert.stub(mock_client.notify).was_called()
      end)

      it("should send workspace config for Ada client", function()
        ada_ls.setup()
        local callback = autocmd_callbacks[1].opts.callback

        local mock_client = {
          name = "ada",
          notify = stub.new(),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)

        local event = {
          data = { client_id = 123 },
        }

        callback(event)

        local call_args = mock_client.notify.calls[1]
        -- vals[1] is self, vals[2] is the first arg due to method call
        assert.is_equal("workspace/didChangeConfiguration", call_args.vals[2])
        local settings = call_args.vals[3]
        assert.is_table(settings)
        assert.is_table(settings.settings)
        assert.is_table(settings.settings.ada)
      end)

      it("should include project file path in config", function()
        ada_ls.setup()
        local callback = autocmd_callbacks[1].opts.callback

        local mock_client = {
          name = "ada",
          notify = stub.new(),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)

        local event = {
          data = { client_id = 123 },
        }

        callback(event)

        local call_args = mock_client.notify.calls[1]
        -- vals[3] is the settings parameter (vals[1]=self, vals[2]=method arg 1)
        local settings = call_args.vals[3]
        assert.is_string(settings.settings.ada.projectFile)
        -- Should contain gnattest and harness paths
        assert.is_true(
          settings.settings.ada.projectFile:find("gnattest") ~= nil
        )
        assert.is_true(
          settings.settings.ada.projectFile:find("test_driver.gpr") ~= nil
        )
      end)

      local error_notification_cases = {
        {
          name = "should notify when client is nil",
          client_return = nil,
        },
        {
          name = "should notify when client is not Ada",
          client_return = { name = "rust_analyzer" },
        },
      }

      for _, case in ipairs(error_notification_cases) do
        it(case.name, function()
          ada_ls.setup()
          local callback = autocmd_callbacks[1].opts.callback
          local utils = require("gnattest.utils")

          _G.vim.lsp.get_client_by_id = stub.new().returns(case.client_return)

          local event = {
            data = { client_id = 123 },
          }

          callback(event)

          assert
            .stub(utils.notify)
            .was_called_with("Ada LSP client not found", _G.vim.log.levels.WARN)
        end)
      end

      it("should get client by event data client_id", function()
        ada_ls.setup()
        local callback = autocmd_callbacks[1].opts.callback

        local mock_client = {
          name = "ada",
          notify = stub.new(),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)

        local event = {
          data = { client_id = 456 },
        }

        callback(event)

        assert.stub(_G.vim.lsp.get_client_by_id).was_called_with(456)
      end)

      it("should extract gnattest directory from buffer path", function()
        local utils_module = require("gnattest.utils")
        local original_get_bufdir = utils_module.get_bufdir

        -- Mock get_bufdir to return a specific path
        utils_module.get_bufdir = function()
          return "/home/user/my_project/gnattest/harness/test_src"
        end

        ada_ls.setup()
        local callback = autocmd_callbacks[1].opts.callback

        local mock_client = {
          name = "ada",
          notify = stub.new(),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)

        local event = {
          data = { client_id = 123 },
        }

        callback(event)

        local call_args = mock_client.notify.calls[1]
        -- vals[3] is the settings parameter (vals[1]=self, vals[2]=method arg 1)
        local settings = call_args.vals[3]
        -- Should find 'gnattest' and use path up to and including 'gnattest'
        assert.string_matches(
          settings.settings.ada.projectFile,
          "/home/user/my_project/gnattest/harness/test_driver.gpr"
        )

        -- Restore
        utils_module.get_bufdir = original_get_bufdir
      end)
    end)
  end)
end)
