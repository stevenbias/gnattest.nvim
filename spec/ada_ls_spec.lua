local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.ada_ls", function()
  local ada_ls
  local autocmd_callbacks = {}

  -- Test data builders for LSP responses
  local function create_lsp_result(data)
    return { result = data }
  end

  local function create_lsp_uri(path)
    return "file://" .. path
  end

  local function create_source_dirs(paths)
    local dirs = {}
    for _, path in ipairs(paths) do
      table.insert(dirs, { uri = create_lsp_uri(path) })
    end
    return create_lsp_result(dirs)
  end

  -- Setup helper for module state
  local function setup_module_state(state)
    for k, v in pairs(state) do
      ada_ls[k] = v
    end
  end

  -- Assertion helpers
  local function assert_lsp_request(client, method)
    assert
      .stub(client.request_sync)
      .was_called_with(client, method, match._, 1000)
  end

  local function assert_lsp_command(client)
    assert
      .stub(client.request_sync)
      .was_called_with(client, "workspace/executeCommand", match.is_table(), 1000)
  end

  before_each(function()
    autocmd_callbacks = {}

    -- Setup vim globals with LSP and utility mocks
    common.setup_vim_globals(
      {
        nvim_create_autocmd = stub.new().invokes(function(event, opts)
          table.insert(autocmd_callbacks, { event = event, opts = opts })
        end),
        nvim__get_runtime = function()
          return {}
        end,
      },
      nil,
      {
        lsp = {
          get_clients = stub.new().returns({}),
          get_client_by_id = stub.new().returns(nil),
          util = {
            make_position_params = stub.new().returns({
              textDocument = { uri = "file:///test.adb" },
              position = { line = 0, character = 0 },
            }),
          },
        },
        log = { levels = { WARN = 3 } },
        uri_to_fname = function(uri)
          return (uri:gsub("file://", ""))
        end,
        islist = function(t)
          return type(t) == "table" and (t[1] ~= nil or next(t) == nil)
        end,
      }
    )

    -- Mock utils module
    common.mock_utils({
      get_bufdir = function()
        return "/home/user/project/gnattest/harness"
      end,
      is_gnattest_file = function()
        return true
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
      assert.is_equal("*.ad[bs]", first_call.opts.pattern[1])
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
          root_dir = "/home/user/project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

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
          root_dir = "/home/user/project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

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
          root_dir = "/home/user/project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

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
          root_dir = "/home/user/my_project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_client_by_id = stub.new().returns(mock_client)
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

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

  describe("get_root_dir()", function()
    it("should return cached root_dir when already set", function()
      local mock_client =
        common.create_lsp_client({ root_dir = "/cached/root" })
      common.setup_lsp_client(mock_client)

      -- First call to set cache
      ada_ls.get_root_dir()

      -- Second call should return cached value
      local call_count_before = #_G.vim.lsp.get_clients.calls
      local result = ada_ls.get_root_dir()

      assert.equals("/cached/root", result)
      assert.equals(call_count_before, #_G.vim.lsp.get_clients.calls)
    end)
  end)

  describe("get_symbols()", function()
    it("should return symbols from LSP document symbol request", function()
      local mock_symbols = {
        { name = "Procedure_One", kind = 6 },
        { name = "Function_Two", kind = 12 },
      }
      local client = common.create_lsp_client({
        request_sync = stub.new().returns(create_lsp_result(mock_symbols)),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_symbols()

      assert.is_not_nil(result)
      assert.equals(2, #result)
      assert_lsp_request(client, "textDocument/documentSymbol")
    end)

    it("should return nil when Ada LSP client not found", function()
      _G.vim.lsp.get_clients = stub.new().returns({})

      local result, err = ada_ls.get_symbols()

      assert.is_nil(result)
      assert.equals("Ada LSP client not found", err)
    end)
  end)

  describe("get_declarations()", function()
    it("should return declarations from LSP request", function()
      local mock_declarations = {
        { uri = "file:///source.ads", range = { start = { line = 10 } } },
      }
      local client = common.create_lsp_client({
        request_sync = stub.new().returns(create_lsp_result(mock_declarations)),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_declarations()

      assert.is_not_nil(result)
      assert_lsp_request(client, "textDocument/declaration")
    end)

    it("should return nil on LSP error", function()
      local client = common.create_lsp_client({
        request_sync = stub.new().returns(nil, "Connection timeout"),
      })
      common.setup_lsp_client(client)

      local result, err = ada_ls.get_declarations()

      assert.is_nil(result)
      assert.is_not_nil(err)
    end)
  end)

  describe("get_prj_file()", function()
    it(
      "should fetch project file via LSP command when not in gnattest",
      function()
        common.mock_gnattest_file(false)

        local client = common.create_lsp_client({
          request_sync = stub.new().returns(
            create_lsp_result({ create_lsp_uri("/project/main.gpr") })
          ),
        })
        common.setup_lsp_client(client)

        local result = ada_ls.get_prj_file()

        assert.equals("/project/main.gpr", result)
        assert_lsp_command(client)
      end
    )
  end)

  describe("get_src_dirs()", function()
    it("should parse and cache source directories from LSP", function()
      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_source_dirs({ "/project/src", "/project/lib" })),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_src_dirs()

      assert.is_not_nil(result)
      assert.equals(2, #result)
      assert.equals("/project/src", result[1])
      assert.equals("/project/lib", result[2])
    end)

    it("should return cached value on subsequent calls", function()
      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_source_dirs({ "/project/src", "/project/lib" })),
      })
      common.setup_lsp_client(client)

      ada_ls.get_src_dirs() -- First call fetches and caches

      local call_count_before = #client.request_sync.calls
      local result = ada_ls.get_src_dirs() -- Second call returns cached

      assert.equals("/project/src", result[1])
      assert.equals(call_count_before, #client.request_sync.calls)
    end)
  end)

  describe("get_obj_dir()", function()
    it("should return cached value and fetch from LSP when empty", function()
      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_lsp_result({ "/project/obj" })),
      })
      common.setup_lsp_client(client)

      -- First call fetches and caches
      local result1 = ada_ls.get_obj_dir()
      assert.equals("/project/obj", result1)

      -- Second call returns cached
      local call_count_before = #client.request_sync.calls
      local result2 = ada_ls.get_obj_dir()
      assert.equals("/project/obj", result2)
      assert.equals(call_count_before, #client.request_sync.calls)
    end)
  end)

  describe("get_harness_dir()", function()
    it("should use custom harness_dir from LSP attribute", function()
      setup_module_state({ obj_dir = "/project/obj" })

      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_lsp_result({ "custom_harness" })),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_harness_dir()

      assert.equals("/project/obj/custom_harness", result)
    end)
  end)

  describe("get_tests_dir()", function()
    it("should use custom tests_dir from LSP attribute", function()
      setup_module_state({ obj_dir = "/project/obj" })

      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_lsp_result({ "custom_tests" })),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_tests_dir()

      assert.equals("/project/obj/custom_tests", result)
    end)

    it("should return cached value on subsequent calls", function()
      setup_module_state({ obj_dir = "/project/obj" })

      local client = common.create_lsp_client({
        request_sync = stub
          .new()
          .returns(create_lsp_result({ "custom_tests" })),
      })
      common.setup_lsp_client(client)

      ada_ls.get_tests_dir() -- First call fetches and caches

      local call_count_before = #client.request_sync.calls
      local result = ada_ls.get_tests_dir() -- Second call returns cached

      assert.equals("/project/obj/custom_tests", result)
      assert.equals(call_count_before, #client.request_sync.calls)
    end)
  end)

  describe("switch_to_source()", function()
    it("should switch to source project file", function()
      common.mock_gnattest_file(true)
      setup_module_state({ prj_file = "/project/source.gpr" })

      local client = common.create_lsp_client()
      common.setup_lsp_client(client)

      ada_ls.switch_to_source()

      assert.stub(client.notify).was_called()
      local call_args = client.notify.calls[1]
      assert.equals("workspace/didChangeConfiguration", call_args.vals[2])
      assert.equals(
        "/project/source.gpr",
        call_args.vals[3].settings.ada.projectFile
      )
    end)

    it("should not switch when not in gnattest file", function()
      common.mock_gnattest_file(false)

      local client = common.create_lsp_client()
      common.setup_lsp_client(client)

      ada_ls.switch_to_source()

      -- Should not call notify when not in gnattest file
      assert.stub(client.notify).was_not_called()
    end)
  end)

  describe("lsp_command result handling", function()
    it("should handle non-list result from LSP command", function()
      -- This test covers line 79: vim.islist check in lsp_command
      common.mock_gnattest_file(false)

      -- Return a single object (not a list) to trigger vim.islist wrapping
      local client = common.create_lsp_client({
        request_sync = stub.new().returns({ result = "single_value_not_list" }),
      })
      common.setup_lsp_client(client)

      local result = ada_ls.get_prj_file()

      -- Should wrap single value in list
      assert.is_not_nil(result)
    end)
  end)
end)
