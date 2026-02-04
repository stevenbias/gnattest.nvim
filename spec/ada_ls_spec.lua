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
    it("should return nil when no Ada clients available", function()
      _G.vim.lsp.get_clients = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_ada_ls())

      _G.vim.lsp.get_clients = stub.new().returns({})
      assert.is_nil(ada_ls.get_ada_ls())
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
      assert.is_equal(mock_client, ada_ls.get_ada_ls())
    end)

    it("should return first client from multiple clients", function()
      local client1 = { name = "ada", id = 1 }
      local client2 = { name = "ada", id = 2 }
      _G.vim.lsp.get_clients = stub.new().returns({ client1, client2 })
      assert.is_equal(client1, ada_ls.get_ada_ls())
    end)

    it("should query LSP with ada name filter", function()
      _G.vim.lsp.get_clients = stub.new().returns({})

      ada_ls.get_ada_ls()

      assert.stub(_G.vim.lsp.get_clients).was_called_with({ name = "ada" })
    end)
  end)

  describe("setup()", function()
    it("should create LspAttach autocmd with Ada file pattern", function()
      ada_ls.setup()

      assert.stub(_G.vim.api.nvim_create_autocmd).was_called()
      local first_call = autocmd_callbacks[1]
      assert.is_equal("LspAttach", first_call.event)
      assert.is_table(first_call.opts.pattern)
      assert.is_equal("*.ad[bs]", first_call.opts.pattern[1])
      assert.is_function(first_call.opts.callback)
    end)

    describe("LspAttach callback", function()
      it("should configure Ada client with workspace settings", function()
        ada_ls.setup()
        local mock_client = {
          name = "ada",
          notify = stub.new(),
          root_dir = "/home/user/project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

        autocmd_callbacks[1].opts.callback({ data = { client_id = 123 } })

        assert.stub(mock_client.notify).was_called()
        local call_args = mock_client.notify.calls[1]
        assert.is_equal("workspace/didChangeConfiguration", call_args.vals[2])
        local settings = call_args.vals[3]
        assert.is_table(settings.settings.ada)
        assert.is_string(settings.settings.ada.projectFile)
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
          client_return = { name = "rust" },
        },
      }

      for _, case in ipairs(error_notification_cases) do
        it(case.name, function()
          local utils = require("gnattest.utils")
          utils.notify = stub.new()
          ada_ls.setup()
          if case.client_return then
            _G.vim.lsp.get_clients = function(filter)
              if filter and filter.name == (case.client_return.name or nil) then
                return {
                  {
                    name = case.client_return.name,
                    request_sync = stub.new().returns(nil),
                    notify = stub.new(),
                  },
                }
              end
            end
          else
            _G.vim.lsp.get_clients = function()
              return {}
            end
          end

          autocmd_callbacks[1].opts.callback({ data = { client_id = 123 } })

          assert
            .stub(utils.notify)
            .was_called_with("Ada LSP client not found", _G.vim.log.levels.WARN)
        end)
      end

      it("should query Ada clients by name filter", function()
        ada_ls.setup()
        local mock_client = {
          name = "ada",
          notify = stub.new(),
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

        autocmd_callbacks[1].opts.callback({ data = { client_id = 456 } })

        assert.stub(_G.vim.lsp.get_clients).was_called_with({ name = "ada" })
      end)

      it("should extract gnattest directory from buffer path", function()
        local utils_module = require("gnattest.utils")
        local original_get_bufdir = utils_module.get_bufdir
        utils_module.get_bufdir = function()
          return "/home/user/my_project/gnattest/harness/test_src"
        end

        ada_ls.setup()
        local mock_client = {
          name = "ada",
          notify = stub.new(),
          root_dir = "/home/user/my_project",
          request_sync = stub.new().returns(nil),
        }
        _G.vim.lsp.get_clients = stub.new().returns({ mock_client })

        autocmd_callbacks[1].opts.callback({ data = { client_id = 123 } })

        local settings = mock_client.notify.calls[1].vals[3]
        assert.string_matches(
          settings.settings.ada.projectFile,
          "/home/user/my_project/gnattest/harness/test_driver.gpr"
        )

        utils_module.get_bufdir = original_get_bufdir
      end)
    end)
  end)

  describe("get_root_dir()", function()
    it("should return cached root_dir when already set", function()
      local mock_client =
        common.create_lsp_client({ root_dir = "/cached/root" })
      common.setup_lsp_client(mock_client)

      ada_ls.get_root_dir()

      local call_count_before = #_G.vim.lsp.get_clients.calls
      local result = ada_ls.get_root_dir()

      assert.equals("/cached/root", result)
      assert.equals(call_count_before, #_G.vim.lsp.get_clients.calls)
    end)
  end)

  describe("get_symbols()", function()
    it("should return symbols from LSP document symbol request", function()
      local client = common.create_lsp_client({
        request_sync = stub.new().returns(create_lsp_result({
          { name = "Procedure_One", kind = 6 },
          { name = "Function_Two", kind = 12 },
        })),
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
      local client = common.create_lsp_client({
        request_sync = stub.new().returns(create_lsp_result({
          { uri = "file:///source.ads", range = { start = { line = 10 } } },
        })),
      })
      common.setup_lsp_client(client)

      assert.is_not_nil(ada_ls.get_declarations())
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
      assert.equals(2, #result)
      assert.equals("/project/src", result[1])

      local call_count = #client.request_sync.calls
      assert.equals("/project/src", ada_ls.get_src_dirs()[1])
      assert.equals(call_count, #client.request_sync.calls)
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

      assert.equals("/project/obj", ada_ls.get_obj_dir())

      local call_count = #client.request_sync.calls
      assert.equals("/project/obj", ada_ls.get_obj_dir())
      assert.equals(call_count, #client.request_sync.calls)
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

      assert.equals("/project/obj/custom_tests", ada_ls.get_tests_dir())

      local call_count = #client.request_sync.calls
      assert.equals("/project/obj/custom_tests", ada_ls.get_tests_dir())
      assert.equals(call_count, #client.request_sync.calls)
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

      assert.stub(client.notify).was_not_called()
    end)
  end)

  describe("lsp_command result handling", function()
    it("should handle non-list result from LSP command", function()
      common.mock_gnattest_file(false)
      local client = common.create_lsp_client({
        request_sync = stub.new().returns({ result = "single_value_not_list" }),
      })
      common.setup_lsp_client(client)

      assert.is_not_nil(ada_ls.get_prj_file())
    end)
  end)
end)
