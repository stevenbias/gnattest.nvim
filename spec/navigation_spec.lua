local stub = require("luassert.stub")
local helpers = require("spec.helpers.common")

describe("gnattest.navigation", function()
  local navigation
  local ada_ls_mock
  local utils_mock
  local xml_mock

  -- Test data builders for readability
  local function create_lsp_symbol(name, start_line, end_line, start_char)
    start_char = start_char or 0
    return {
      name = name,
      range = {
        start = { line = start_line, character = start_char },
        ["end"] = { line = end_line, character = 0 },
      },
      selectionRange = {
        start = { line = start_line, character = start_char },
        ["end"] = { line = start_line, character = start_char + #name },
      },
    }
  end

  local function create_lsp_declaration(
    filepath,
    line,
    column,
    end_line,
    end_col
  )
    return {
      uri = "file://" .. filepath,
      range = {
        start = { line = line, character = column },
        ["end"] = { line = end_line or line, character = end_col or column },
      },
    }
  end

  local function create_xml_test_entry(source_name, test_name, opts)
    opts = opts or {}
    return {
      source = {
        name = source_name,
        line = opts.source_line or 10,
        column = opts.source_column or 5,
      },
      test = {
        name = test_name,
        file = opts.test_file or "test_file.adb",
        line = opts.test_line or 20,
        column = opts.test_column or 10,
      },
    }
  end

  local function setup_default_mocks()
    ada_ls_mock.get_symbols.returns(nil)
    ada_ls_mock.get_declarations.returns(nil)
    xml_mock.get_xml_info.returns({})
    utils_mock.is_gnattest_file.returns(false)
    utils_mock.get_filename.returns("my_package.ads")
  end

  before_each(function()
    package.loaded["gnattest.navigation"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.loaded["gnattest.utils"] = nil
    package.loaded["gnattest.xml"] = nil

    helpers.setup_vim_globals({
      nvim_win_set_cursor = stub.new(),
      nvim__get_runtime = function()
        return {}
      end,
    }, {
      getpos = stub.new().returns({ 0, 5, 10 }),
      match = stub.new().invokes(function(str, pattern)
        if type(str) == "string" and type(pattern) == "string" then
          if str:find(pattern, 1, true) then
            return 0
          end
        end
        return -1
      end),
    }, {
      cmd = stub.new(),
      uri_to_fname = stub.new().invokes(function(uri)
        if type(uri) == "string" then
          return uri:gsub("file://", "")
        end
        return uri
      end),
      fs = {
        basename = stub.new().invokes(function(path)
          if type(path) == "string" then
            return path:match("([^/]+)$") or path
          end
          return path
        end),
      },
    })
    utils_mock = {
      notify = stub.new(),
      get_filename = stub.new().returns("my_package.ads"),
      is_gnattest_file = stub.new().returns(false),
      find_file = stub.new().returns("/project/src/my_package.ads"),
    }
    package.loaded["gnattest.utils"] = utils_mock

    ada_ls_mock = {
      get_symbols = stub.new(),
      get_declarations = stub.new(),
      get_src_dirs = stub.new().returns({ "/project/src" }),
      get_tests_dir = stub.new().returns("/project/gnattest/tests"),
      switch_to_source = stub.new(),
      switch_to_tests = stub.new(),
      root_dir = "",
      prj_file = "",
      src_dirs = {},
      obj_dir = "",
      harness_dir = "",
      tests_dir = "",
    }
    package.loaded["gnattest.ada_ls"] = ada_ls_mock

    xml_mock = {
      get_xml_info = stub.new().returns({}),
    }
    package.loaded["gnattest.xml"] = xml_mock

    navigation = require("gnattest.navigation")

    setup_default_mocks()
  end)

  after_each(function()
    helpers.cleanup_packages()
    package.loaded["gnattest.navigation"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.loaded["gnattest.xml"] = nil
  end)

  -- Tests for private functions (requires GNATTEST_TEST_MODE=1)
  if os.getenv("GNATTEST_TEST_MODE") then
    describe("_get_subprogram_name (private)", function()
      it("returns nil when no matching symbols", function()
        ada_ls_mock.get_symbols.returns(nil)
        assert.is_nil(navigation._get_subprogram_name())

        ada_ls_mock.get_symbols.returns({})
        assert.is_nil(navigation._get_subprogram_name())

        local symbol = create_lsp_symbol("My_Function", 10, 15, 9)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        assert.is_nil(navigation._get_subprogram_name())
      end)

      it("returns subprogram name when cursor is on exact line", function()
        local symbol = create_lsp_symbol("My_Function", 4, 15, 9)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })

        local result = navigation._get_subprogram_name()

        assert.equals("My_Function", result)
      end)

      it("returns subprogram name and position when inside range", function()
        local symbol = create_lsp_symbol("My_Procedure", 3, 20, 9)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })

        local name, pos = navigation._get_subprogram_name()

        assert.equals("My_Procedure", name)
        assert.same({ 4, 10 }, pos)
      end)

      it("uses selectionRange when range is not available", function()
        local symbol = {
          name = "Another_Function",
          selectionRange = {
            start = { line = 4, character = 0 },
            ["end"] = { line = 10, character = 0 },
          },
        }
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })

        local result = navigation._get_subprogram_name()

        assert.equals("Another_Function", result)
      end)

      it("handles multiple symbols and returns first match", function()
        local symbols = {
          create_lsp_symbol("First_Function", 10, 15, 0),
          create_lsp_symbol("Second_Function", 3, 8, 0),
        }
        ada_ls_mock.get_symbols.returns({ { children = symbols } })

        local result = navigation._get_subprogram_name()

        assert.equals("Second_Function", result)
      end)
    end)

    describe("_get_declaration_info (private)", function()
      it("returns nil when get_declarations returns nil", function()
        ada_ls_mock.get_declarations.returns(nil)
        assert.is_nil(navigation._get_declaration_info())
      end)

      it("returns empty array when get_declarations returns empty", function()
        ada_ls_mock.get_declarations.returns({})
        assert.same({}, navigation._get_declaration_info())
      end)

      it("parses declaration with uri and range", function()
        ada_ls_mock.get_declarations.returns({
          create_lsp_declaration("/project/src/my_package.ads", 10, 5, 15, 20),
        })
        local result = navigation._get_declaration_info()
        assert.equals(1, #result)
        assert.equals("/project/src/my_package.ads", result[1].filepath)
        assert.equals(11, result[1].line)
        assert.equals(5, result[1].column)
      end)

      it("parses declaration with targetUri and targetRange", function()
        ada_ls_mock.get_declarations.returns({
          {
            targetUri = "file:///project/src/another.adb",
            targetRange = {
              start = { line = 5, character = 0 },
              ["end"] = { line = 10, character = 10 },
            },
          },
        })
        local result = navigation._get_declaration_info()
        assert.equals(1, #result)
        assert.equals("/project/src/another.adb", result[1].filepath)
        assert.equals(6, result[1].line)
      end)

      it("handles multiple declarations", function()
        ada_ls_mock.get_declarations.returns({
          create_lsp_declaration("/project/src/file1.ads", 1, 0, 2, 0),
          create_lsp_declaration("/project/src/file2.adb", 3, 5, 4, 10),
        })
        local result = navigation._get_declaration_info()
        assert.equals(2, #result)
        assert.equals("/project/src/file1.ads", result[1].filepath)
        assert.equals("/project/src/file2.adb", result[2].filepath)
      end)
    end)

    describe("_get_gnattest_info_on_cursor (private)", function()
      it("returns nil when prerequisites missing", function()
        xml_mock.get_xml_info.returns({})
        assert.is_nil(navigation._get_gnattest_info_on_cursor())

        xml_mock.get_xml_info.returns({ ["my_package.ads"] = {} })
        ada_ls_mock.get_symbols.returns(nil)
        assert.is_nil(navigation._get_gnattest_info_on_cursor())
      end)

      it("searches by test name when in gnattest file", function()
        utils_mock.is_gnattest_file.returns(true)
        local test_entry =
          create_xml_test_entry("My_Function", "Test_My_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("Test_My_Function", 4, 10, 0)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })

        local result = navigation._get_gnattest_info_on_cursor()

        assert.is_not_nil(result)
        assert.is_not_nil(result["my_package.ads"])
        assert.equals("My_Function", result["my_package.ads"].source.name)
      end)

      it("searches by source name when not in gnattest file", function()
        utils_mock.is_gnattest_file.returns(false)
        utils_mock.get_filename.returns("my_package.ads")
        local test_entry =
          create_xml_test_entry("My_Function", "Test_My_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("My_Function", 4, 10, 0)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        local decl =
          create_lsp_declaration("/project/src/my_package.ads", 5, 0, 10, 0)
        ada_ls_mock.get_declarations.returns({ decl })

        local result = navigation._get_gnattest_info_on_cursor()

        assert.is_not_nil(result)
        assert.is_not_nil(result["my_package.ads"])
        assert.equals("My_Function", result["my_package.ads"].source.name)
      end)

      it("returns nil when no matching subprogram in xml", function()
        utils_mock.is_gnattest_file.returns(false)
        utils_mock.get_filename.returns("my_package.ads")
        local test_entry =
          create_xml_test_entry("Other_Function", "Test_Other_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("My_Function", 4, 10, 0)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        local decl =
          create_lsp_declaration("/project/src/my_package.ads", 5, 0, 10, 0)
        ada_ls_mock.get_declarations.returns({ decl })

        local result = navigation._get_gnattest_info_on_cursor()

        assert.is_nil(result)
      end)

      it("uses declaration filename when not in gnattest file", function()
        utils_mock.is_gnattest_file.returns(false)
        utils_mock.get_filename.returns("my_package.adb")
        local test_entry =
          create_xml_test_entry("My_Function", "Test_My_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("My_Function", 3, 10, 0)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        local decl =
          create_lsp_declaration("/project/src/my_package.ads", 5, 0, 10, 0)
        ada_ls_mock.get_declarations.returns({ decl })

        local result = navigation._get_gnattest_info_on_cursor()

        assert.is_not_nil(result)
        assert.stub(ada_ls_mock.get_declarations).was_called()
      end)

      it("sets cursor position when start_pos is available", function()
        utils_mock.is_gnattest_file.returns(false)
        local test_entry =
          create_xml_test_entry("My_Function", "Test_My_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("My_Function", 2, 10, 5)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        local decl =
          create_lsp_declaration("/project/src/my_package.ads", 5, 0, 10, 0)
        ada_ls_mock.get_declarations.returns({ decl })

        navigation._get_gnattest_info_on_cursor()

        assert.stub(_G.vim.api.nvim_win_set_cursor).was_called_with(0, { 3, 6 })
      end)

      it("returns nil when declaration_info is nil", function()
        utils_mock.is_gnattest_file.returns(false)
        local test_entry =
          create_xml_test_entry("My_Function", "Test_My_Function")
        xml_mock.get_xml_info.returns({
          ["my_package.ads"] = { ["Package1"] = { test_entry } },
        })
        local symbol = create_lsp_symbol("My_Function", 2, 10, 5)
        ada_ls_mock.get_symbols.returns({ { children = { symbol } } })
        ada_ls_mock.get_declarations.returns({})

        local result = navigation._get_gnattest_info_on_cursor()

        assert.is_nil(result)
      end)
    end)
  end -- if os.getenv("GNATTEST_TEST_MODE")

  describe("switch_subprogram", function()
    it("returns nil when get_gnattest_info_on_cursor returns nil", function()
      xml_mock.get_xml_info.returns({})
      assert.is_nil(navigation.switch_subprogram())
    end)

    it("switches to source file when in gnattest file", function()
      utils_mock.is_gnattest_file.returns(true)
      xml_mock.get_xml_info.returns({
        ["my_package.ads"] = {
          ["Package1"] = {
            create_xml_test_entry("My_Function", "Test_My_Function", {
              source_line = 15,
              source_column = 8,
              test_line = 25,
              test_column = 12,
            }),
          },
        },
      })
      ada_ls_mock.get_symbols.returns({
        { children = { create_lsp_symbol("Test_My_Function", 4, 10, 0) } },
      })
      utils_mock.find_file.returns("/project/src/my_package.ads")

      navigation.switch_subprogram()

      assert.stub(utils_mock.find_file).was_called()
      assert.stub(ada_ls_mock.switch_to_source).was_called()
      assert
        .stub(_G.vim.cmd)
        .was_called_with("edit /project/src/my_package.ads")
      assert.stub(_G.vim.api.nvim_win_set_cursor).was_called_with(0, { 15, 8 })
    end)

    it("returns nil when src_dirs not available", function()
      utils_mock.is_gnattest_file.returns(true)
      xml_mock.get_xml_info.returns({
        ["my_package.ads"] = {
          ["Package1"] = {
            create_xml_test_entry("My_Function", "Test_My_Function"),
          },
        },
      })
      ada_ls_mock.get_symbols.returns({
        { children = { create_lsp_symbol("Test_My_Function", 4, 10, 0) } },
      })
      ada_ls_mock.get_src_dirs.returns(nil)

      local result = navigation.switch_subprogram()

      assert.is_nil(result)
      assert.stub(ada_ls_mock.get_src_dirs).was_called()
    end)

    it("switches to test file when in source file", function()
      utils_mock.is_gnattest_file.returns(false)
      utils_mock.get_filename.returns("my_package.ads")
      xml_mock.get_xml_info.returns({
        ["my_package.ads"] = {
          ["Package1"] = {
            create_xml_test_entry("My_Function", "Test_My_Function", {
              source_line = 15,
              source_column = 8,
              test_line = 25,
              test_column = 12,
            }),
          },
        },
      })
      ada_ls_mock.get_symbols.returns({
        { children = { create_lsp_symbol("My_Function", 4, 10, 0) } },
      })
      ada_ls_mock.get_declarations.returns({
        create_lsp_declaration("/project/src/my_package.ads", 5, 0, 10, 0),
      })

      navigation.switch_subprogram()

      assert.stub(ada_ls_mock.switch_to_tests).was_called()
      assert
        .stub(_G.vim.cmd)
        .was_called_with("edit /project/gnattest/tests/test_file.adb")
      assert.stub(_G.vim.api.nvim_win_set_cursor).was_called_with(0, { 25, 12 })
    end)

    it("handles multiple file entries correctly", function()
      utils_mock.is_gnattest_file.returns(true)
      xml_mock.get_xml_info.returns({
        ["my_package.ads"] = {
          ["Package1"] = {
            create_xml_test_entry("My_Function", "Test_My_Function"),
          },
        },
      })
      ada_ls_mock.get_symbols.returns({
        { children = { create_lsp_symbol("Test_My_Function", 4, 10, 0) } },
      })

      navigation.switch_subprogram()

      assert.stub(_G.vim.cmd).was_called(1)
      assert.stub(_G.vim.api.nvim_win_set_cursor).was_called(1)
    end)
  end)
end)
