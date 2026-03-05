local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.ada_ls", function()
  local ada_ls

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
    common.setup_vim_globals(
      {
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
      assert.is_equal("Ada Language Server not found", call_args.vals[1])
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
    it("initializes module state on first setup", function()
      local utils = require("gnattest.utils")
      local original_is_gnattest_file = utils.is_gnattest_file
      local set_pattern_stub = stub(utils, "set_gnattest_pattern")

      utils.is_gnattest_file = stub.new().returns(false)

      local stubs = {
        get_root_dir = stub(ada_ls, "get_root_dir").returns("/root"),
        get_prj_file = stub(ada_ls, "get_prj_file").returns(
          "/project/main.gpr"
        ),
        get_src_dirs = stub(ada_ls, "get_src_dirs").returns({ "/src" }),
        get_obj_dir = stub(ada_ls, "get_obj_dir").returns("/project/obj"),
        get_harness_dir = stub(ada_ls, "get_harness_dir").returns(
          "/project/obj/harness"
        ),
        get_tests_dir = stub(ada_ls, "get_tests_dir").returns(
          "/project/obj/tests"
        ),
      }

      ada_ls.is_init = false

      ada_ls.setup()

      assert.is_true(ada_ls.is_init)
      assert.equals("/root", ada_ls.root_dir)
      assert.equals("/project/main.gpr", ada_ls.prj_file)
      assert.same({ "/src" }, ada_ls.src_dirs)
      assert.equals("/project/obj", ada_ls.obj_dir)
      assert.equals("/project/obj/harness", ada_ls.harness_dir)
      assert.equals("/project/obj/tests", ada_ls.tests_dir)
      assert.stub(set_pattern_stub).was_called()

      set_pattern_stub:revert()
      utils.is_gnattest_file = original_is_gnattest_file
      for _, stubbed in pairs(stubs) do
        stubbed:revert()
      end
    end)

    it("switches to tests when current file is gnattest", function()
      setup_module_state({
        is_init = true,
        harness_dir = "/project/obj/gnattest/harness",
      })
      local client = common.create_lsp_client()
      common.setup_lsp_client(client)

      ada_ls.setup()

      assert.stub(client.notify).was_called()
      local call_args = client.notify.calls[1]
      assert.equals("workspace/didChangeConfiguration", call_args.vals[2])
      assert.equals(
        "/project/obj/gnattest/harness/test_driver.gpr",
        call_args.vals[3].settings.ada.projectFile
      )
    end)

    it("does not switch when current file is not gnattest", function()
      local utils = require("gnattest.utils")
      utils.is_gnattest_file = stub.new().returns(false)
      setup_module_state({
        is_init = true,
        harness_dir = "/project/obj/gnattest/harness",
      })
      local client = common.create_lsp_client()
      common.setup_lsp_client(client)

      ada_ls.setup()

      assert.stub(client.notify).was_not_called()
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

    it("returns empty string when no client", function()
      _G.vim.lsp.get_clients = stub.new().returns({})
      assert.equals("", ada_ls.get_root_dir())
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

    it("should return nil when Ada Language Server not found", function()
      _G.vim.lsp.get_clients = stub.new().returns({})
      local result, err = ada_ls.get_symbols()
      assert.is_nil(result)
      assert.equals("Ada Language Server not found", err)
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

    it("returns cached project file when in gnattest file", function()
      common.mock_gnattest_file(true)
      setup_module_state({ prj_file = "/project/cached.gpr" })

      assert.equals("/project/cached.gpr", ada_ls.get_prj_file())
    end)

    it("returns empty string when LSP command fails", function()
      common.mock_gnattest_file(false)
      local client = common.create_lsp_client({
        request_sync = stub.new().returns({ result = nil }),
      })
      common.setup_lsp_client(client)

      assert.equals("", ada_ls.get_prj_file())
    end)
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

    it("returns nil when source dirs command fails", function()
      _G.vim.lsp.get_clients = stub.new().returns({})
      assert.is_nil(ada_ls.get_src_dirs())
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

    it("returns empty string when obj dir command fails", function()
      _G.vim.lsp.get_clients = stub.new().returns({})
      assert.equals("", ada_ls.get_obj_dir())
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

    it("falls back to default harness dir when command fails", function()
      setup_module_state({ obj_dir = "/project/obj" })
      _G.vim.lsp.get_clients = stub.new().returns({})

      assert.equals("/project/obj/gnattest/harness", ada_ls.get_harness_dir())
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

    it("falls back to default tests dir when command fails", function()
      setup_module_state({ obj_dir = "/project/obj" })
      _G.vim.lsp.get_clients = stub.new().returns({})

      assert.equals("/project/obj/gnattest/tests", ada_ls.get_tests_dir())
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

    it("should switch even when not in gnattest file", function()
      common.mock_gnattest_file(false)
      setup_module_state({ prj_file = "/project/source.gpr" })
      local client = common.create_lsp_client()
      common.setup_lsp_client(client)

      ada_ls.switch_to_source()

      assert.stub(client.notify).was_called()
      local call_args = client.notify.calls[1]
      assert.equals(
        "/project/source.gpr",
        call_args.vals[3].settings.ada.projectFile
      )
    end)

    it("notifies when no ada client is available", function()
      setup_module_state({ prj_file = "/project/source.gpr" })
      _G.vim.lsp.get_clients = stub.new().returns({})
      local utils = require("gnattest.utils")

      ada_ls.switch_to_source()

      assert.stub(utils.notify).was_called()
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

  describe("get_subprogram_name_from_line()", function()
    local function symbol(name, start_line, end_line, start_char)
      return {
        name = name,
        range = {
          start = { line = start_line, character = start_char or 0 },
          ["end"] = { line = end_line, character = 0 },
        },
        selectionRange = {
          start = { line = start_line, character = start_char or 0 },
          ["end"] = { line = end_line, character = 0 },
        },
      }
    end

    it("returns nil when symbols are missing", function()
      stub(ada_ls, "get_symbols").returns(nil)
      assert.is_nil(ada_ls.get_subprogram_name_from_line(3))
      ada_ls.get_symbols:revert()
    end)

    it("matches exact start line", function()
      stub(ada_ls, "get_symbols").returns({
        { children = { symbol("My_Function", 2, 5, 1) } },
      })

      assert.equals("My_Function", ada_ls.get_subprogram_name_from_line(3))
      ada_ls.get_symbols:revert()
    end)

    it("matches within range and returns position", function()
      stub(ada_ls, "get_symbols").returns({
        { children = { symbol("My_Procedure", 1, 6, 4) } },
      })

      local name, pos = ada_ls.get_subprogram_name_from_line(4)

      assert.equals("My_Procedure", name)
      assert.same({ 2, 5 }, pos)
      ada_ls.get_symbols:revert()
    end)

    it("returns nil when no symbols match line", function()
      stub(ada_ls, "get_symbols").returns({
        { children = { symbol("Other_Function", 10, 12, 0) } },
      })

      assert.is_nil(ada_ls.get_subprogram_name_from_line(3))
      ada_ls.get_symbols:revert()
    end)
  end)
end)
