local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.ada_ls", function()
  local ada_ls
  local lsp_cmd_mock
  local ada_ls_utils_mock

  -- Setup helper for module state
  local function setup_module_state(state)
    for k, v in pairs(state) do
      ada_ls[k] = v
    end
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
        log = { levels = { WARN = 3, ERROR = 4 } },
        uri_to_fname = function(uri)
          return (uri:gsub("file://", ""))
        end,
        islist = function(t)
          return type(t) == "table" and (t[1] ~= nil or next(t) == nil)
        end,
      }
    )

    -- Mock ada_ls.lsp_cmd (external dependency)
    lsp_cmd_mock = {
      get_root_dir = stub.new().returns("/project/root"),
      get_prj_file = stub.new().returns("file:///project/main.gpr"),
      get_src_dirs = stub.new().returns({
        { uri = "file:///project/src" },
      }),
      get_obj_dir = stub.new().returns("/project/obj"),
      get_symbols = stub.new().returns(nil),
      get_declarations = stub.new().returns(nil),
      send_command = stub.new().returns(nil),
    }
    package.preload["ada_ls.lsp_cmd"] = function()
      return lsp_cmd_mock
    end

    -- Mock ada_ls.utils (external dependency)
    ada_ls_utils_mock = {
      get_ada_ls = stub.new().returns(nil),
      notify_server = stub.new().returns(true),
    }
    package.preload["ada_ls.utils"] = function()
      return ada_ls_utils_mock
    end

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
    package.loaded["ada_ls.lsp_cmd"] = nil
    package.loaded["ada_ls.utils"] = nil
    package.preload["ada_ls.lsp_cmd"] = nil
    package.preload["ada_ls.utils"] = nil
  end)

  describe("get_ada_ls()", function()
    it("should delegate to ada_ls.utils.get_ada_ls()", function()
      local mock_client = { name = "ada", id = 1 }
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(mock_client)

      local result = ada_ls.get_ada_ls()

      assert.equals(mock_client, result)
      assert.stub(ada_ls_utils_mock.get_ada_ls).was_called()
    end)

    it("should return nil when ada_ls.utils returns nil", function()
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_ada_ls())
    end)
  end)

  describe("setup()", function()
    it("initializes module state on first setup", function()
      local utils = require("gnattest.utils")
      utils.is_gnattest_file = stub.new().returns(false)

      ada_ls.is_init = false

      ada_ls.setup()

      assert.is_true(ada_ls.is_init)
    end)

    it("switches to tests when current file is gnattest", function()
      setup_module_state({
        is_init = true,
        harness_dir = "/project/obj/gnattest/harness",
      })
      local mock_client = { name = "ada", id = 1 }
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(mock_client)

      ada_ls.setup()

      assert.stub(ada_ls_utils_mock.notify_server).was_called()
      local call_args = ada_ls_utils_mock.notify_server.calls[1]
      assert.equals("workspace/didChangeConfiguration", call_args.vals[1])
      assert.equals(
        "/project/obj/gnattest/harness/test_driver.gpr",
        call_args.vals[2].settings.ada.projectFile
      )
    end)

    it("does not switch when current file is not gnattest", function()
      local utils = require("gnattest.utils")
      utils.is_gnattest_file = stub.new().returns(false)
      setup_module_state({
        is_init = true,
        harness_dir = "/project/obj/gnattest/harness",
      })

      ada_ls.setup()

      assert.stub(ada_ls_utils_mock.notify_server).was_not_called()
    end)
  end)

  describe("get_root_dir()", function()
    it("should return cached root_dir when already set", function()
      ada_ls.root_dir = "/cached/root"

      local result = ada_ls.get_root_dir()

      assert.equals("/cached/root", result)
      assert.stub(lsp_cmd_mock.get_root_dir).was_not_called()
    end)

    it("should delegate to ada_ls.lsp_cmd when not cached", function()
      ada_ls.root_dir = ""
      lsp_cmd_mock.get_root_dir = stub.new().returns("/project/root")

      local result = ada_ls.get_root_dir()

      assert.equals("/project/root", result)
      assert.stub(lsp_cmd_mock.get_root_dir).was_called()
    end)
  end)

  describe("get_symbols()", function()
    it("should delegate to ada_ls.lsp_cmd.get_symbols()", function()
      local symbols = {
        { name = "Procedure_One", kind = 6 },
        { name = "Function_Two", kind = 12 },
      }
      lsp_cmd_mock.get_symbols = stub.new().returns(symbols)

      local result = ada_ls.get_symbols()

      assert.is_not_nil(result)
      assert.equals(2, #result)
      assert.stub(lsp_cmd_mock.get_symbols).was_called()
    end)

    it("should return nil when lsp_cmd returns nil", function()
      lsp_cmd_mock.get_symbols = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_symbols())
    end)
  end)

  describe("get_declarations()", function()
    it("should delegate to ada_ls.lsp_cmd.get_declarations()", function()
      local decls = {
        { uri = "file:///source.ads", range = { start = { line = 10 } } },
      }
      lsp_cmd_mock.get_declarations = stub.new().returns(decls)

      local result = ada_ls.get_declarations()

      assert.is_not_nil(result)
      assert.stub(lsp_cmd_mock.get_declarations).was_called()
    end)

    it("should return nil when lsp_cmd returns nil", function()
      lsp_cmd_mock.get_declarations = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_declarations())
    end)
  end)

  describe("get_prj_file()", function()
    it("should fetch and cache project file via lsp_cmd", function()
      ada_ls.prj_file = ""
      lsp_cmd_mock.get_prj_file = stub.new().returns("file:///project/main.gpr")

      local result = ada_ls.get_prj_file()

      assert.equals("/project/main.gpr", result)
      assert.stub(lsp_cmd_mock.get_prj_file).was_called()
    end)

    it("returns cached project file on subsequent calls", function()
      ada_ls.prj_file = "/project/cached.gpr"

      assert.equals("/project/cached.gpr", ada_ls.get_prj_file())
      assert.stub(lsp_cmd_mock.get_prj_file).was_not_called()
    end)

    it("returns empty string when lsp_cmd returns nil", function()
      ada_ls.prj_file = ""
      lsp_cmd_mock.get_prj_file = stub.new().returns(nil)

      assert.equals("", ada_ls.get_prj_file())
    end)
  end)

  describe("get_src_dirs()", function()
    it("should parse and cache source directories from lsp_cmd", function()
      ada_ls.src_dirs = {}
      lsp_cmd_mock.get_src_dirs = stub.new().returns({
        { uri = "file:///project/src" },
        { uri = "file:///project/lib" },
      })

      local result = ada_ls.get_src_dirs()

      assert.equals(2, #result)
      assert.equals("/project/src", result[1])
      assert.equals("/project/lib", result[2])

      -- Second call should use cache
      lsp_cmd_mock.get_src_dirs = stub.new().returns(nil)
      local result2 = ada_ls.get_src_dirs()
      assert.equals(2, #result2)
      assert.stub(lsp_cmd_mock.get_src_dirs).was_not_called()
    end)

    it("returns nil when lsp_cmd returns nil", function()
      ada_ls.src_dirs = {}
      lsp_cmd_mock.get_src_dirs = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_src_dirs())
    end)
  end)

  describe("get_obj_dir()", function()
    it("should cache and return obj_dir from lsp_cmd", function()
      ada_ls.obj_dir = nil
      lsp_cmd_mock.get_obj_dir = stub.new().returns("/project/obj")

      assert.equals("/project/obj", ada_ls.get_obj_dir())

      -- Second call should use cache
      lsp_cmd_mock.get_obj_dir = stub.new().returns(nil)
      assert.equals("/project/obj", ada_ls.get_obj_dir())
      assert.stub(lsp_cmd_mock.get_obj_dir).was_not_called()
    end)

    it("returns nil when lsp_cmd returns nil", function()
      ada_ls.obj_dir = nil
      lsp_cmd_mock.get_obj_dir = stub.new().returns(nil)
      assert.is_nil(ada_ls.get_obj_dir())
    end)
  end)

  describe("get_harness_dir()", function()
    it("should use custom harness_dir from LSP attribute", function()
      setup_module_state({ obj_dir = "/project/obj" })
      lsp_cmd_mock.send_command = stub.new().returns({ "custom_harness" })

      local result = ada_ls.get_harness_dir()

      assert.equals("/project/obj/custom_harness", result)
    end)

    it(
      "falls back to default harness dir when send_command returns nil",
      function()
        setup_module_state({ obj_dir = "/project/obj" })
        lsp_cmd_mock.send_command = stub.new().returns(nil)

        assert.equals("/project/obj/gnattest/harness", ada_ls.get_harness_dir())
      end
    )

    it("returns cached harness_dir on subsequent calls", function()
      ada_ls.harness_dir = "/cached/harness"

      assert.equals("/cached/harness", ada_ls.get_harness_dir())
      assert.stub(lsp_cmd_mock.send_command).was_not_called()
    end)
  end)

  describe("get_tests_dir()", function()
    it("should use custom tests_dir from LSP attribute", function()
      setup_module_state({ obj_dir = "/project/obj" })
      lsp_cmd_mock.send_command = stub.new().returns({ "custom_tests" })

      local result = ada_ls.get_tests_dir()

      assert.equals("/project/obj/custom_tests", result)
    end)

    it(
      "falls back to default tests dir when send_command returns nil",
      function()
        setup_module_state({ obj_dir = "/project/obj" })
        lsp_cmd_mock.send_command = stub.new().returns(nil)

        assert.equals("/project/obj/gnattest/tests", ada_ls.get_tests_dir())
      end
    )

    it("returns cached tests_dir on subsequent calls", function()
      ada_ls.tests_dir = "/cached/tests"

      assert.equals("/cached/tests", ada_ls.get_tests_dir())
      assert.stub(lsp_cmd_mock.send_command).was_not_called()
    end)
  end)

  describe("switch_to_source()", function()
    it("should switch to source project file", function()
      setup_module_state({ prj_file = "/project/source.gpr" })
      local mock_client = { name = "ada", id = 1 }
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(mock_client)

      ada_ls.switch_to_source()

      assert.stub(ada_ls_utils_mock.notify_server).was_called()
      local call_args = ada_ls_utils_mock.notify_server.calls[1]
      assert.equals("workspace/didChangeConfiguration", call_args.vals[1])
      assert.equals(
        "/project/source.gpr",
        call_args.vals[2].settings.ada.projectFile
      )
    end)

    it("does not notify server when no ada client is available", function()
      setup_module_state({ prj_file = "/project/source.gpr" })
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(nil)

      ada_ls.switch_to_source()

      assert.stub(ada_ls_utils_mock.notify_server).was_not_called()
    end)
  end)

  describe("switch_to_tests()", function()
    it("should switch to test driver project file", function()
      setup_module_state({ harness_dir = "/project/obj/harness" })
      local mock_client = { name = "ada", id = 1 }
      ada_ls_utils_mock.get_ada_ls = stub.new().returns(mock_client)

      ada_ls.switch_to_tests()

      assert.stub(ada_ls_utils_mock.notify_server).was_called()
      local call_args = ada_ls_utils_mock.notify_server.calls[1]
      assert.equals("workspace/didChangeConfiguration", call_args.vals[1])
      assert.equals(
        "/project/obj/harness/test_driver.gpr",
        call_args.vals[2].settings.ada.projectFile
      )
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
