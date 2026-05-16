local common = require("spec.helpers.common")

describe("gnattest.runner", function()
  local runner
  local ada_ls_mock
  local utils_mock
  local xml_mock

  local function mock_build_success()
    _G.vim.system = require("luassert.stub").new().returns({
      wait = function()
        return { stderr = "", stdout = "", code = 0 }
      end,
    })
  end

  local function mock_build_failure()
    _G.vim.system = require("luassert.stub").new().returns({
      wait = function()
        return { stderr = "build error", stdout = "", code = 1 }
      end,
    })
  end

  local function mock_system_async()
    _G.vim.system = require("luassert.stub").new()
  end

  before_each(function()
    package.loaded["gnattest.runner"] = nil
    package.loaded["gnattest.utils"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.loaded["gnattest.xml"] = nil

    _G.vim = _G.vim or {}
    _G.vim.schedule = function(cb)
      cb()
    end
    _G.vim.fn = {
      setqflist = require("luassert.stub").new(),
    }
    _G.vim.cmd = require("luassert.stub").new()
    _G.vim.log = {
      levels = { WARN = 3, ERROR = 4 },
    }
    _G.vim.split = function(str, delimiter)
      local parts = {}
      for part in str:gmatch("[^" .. delimiter .. "]+") do
        table.insert(parts, part)
      end
      return parts
    end
    _G.print = require("luassert.stub").new()

    utils_mock = {
      get_gnattest_project = require("luassert.stub")
        .new()
        .returns("project.gpr"),
      notify = require("luassert.stub").new(),
      find_file = require("luassert.stub").new().returns("/found/file.adb"),
    }
    package.loaded["gnattest.utils"] = utils_mock

    ada_ls_mock = {
      get_tests_dir = require("luassert.stub").new().returns("/test/dir"),
      get_harness_dir = require("luassert.stub").new().returns("/harness/dir"),
    }
    package.loaded["gnattest.ada_ls"] = ada_ls_mock

    xml_mock = {
      get_test_from_src_file_line = require("luassert.stub")
        .new()
        .returns(nil, nil, nil),
    }
    package.loaded["gnattest.xml"] = xml_mock

    runner = require("gnattest.runner")
  end)

  after_each(function()
    common.cleanup_packages()
    package.loaded["gnattest.runner"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.loaded["gnattest.xml"] = nil
  end)

  describe("build_tests()", function()
    it("returns true on successful build", function()
      mock_build_success()

      local result = runner.build_tests()

      assert.is_true(result)
      assert.stub(_G.vim.system).was_called()
      assert.stub(_G.print).was_called_with("Tests built successfully")
    end)

    it("returns false on build failure", function()
      mock_build_failure()

      local result = runner.build_tests()

      assert.is_false(result)
      assert.stub(_G.print).was_called_with("Error building tests: build error")
    end)

    it("calls gprbuild with the gnattest project", function()
      mock_build_success()

      runner.build_tests()

      assert
        .stub(_G.vim.system)
        .was_called_with({ "gprbuild", "-Pproject.gpr" }, { text = true })
    end)
  end)

  describe("prepare_run()", function()
    it("returns true and clears quickfix when build succeeds", function()
      mock_build_success()

      local result = runner.prepare_run()

      assert.is_true(result)
      assert.stub(_G.vim.fn.setqflist).was_called_with({}, "r")
    end)

    it("returns false when build fails", function()
      mock_build_failure()

      local result = runner.prepare_run()

      assert.is_false(result)
      assert.stub(_G.vim.fn.setqflist).was_not_called()
    end)

    it("returns false when there are pending runs", function()
      mock_system_async()
      runner.run_test()

      mock_build_success()
      local result = runner.prepare_run()

      assert.is_false(result)
    end)
  end)

  describe("run_test()", function()
    it("calls system with harness path and --routines", function()
      mock_system_async()

      runner.run_test("source.ads", 42)

      assert.stub(_G.vim.system).was_called()
      local call = _G.vim.system.calls[1]
      -- vim.system receives: {command...}, {options}, callback
      assert.equals("/harness/dir/test_runner", call.vals[1][1])
      assert.equals("--routines=source.ads:42", call.vals[1][2])
    end)

    it("passes empty routines arg when no filename given", function()
      mock_system_async()

      runner.run_test()

      local call = _G.vim.system.calls[1]
      assert.equals("", call.vals[1][2])
    end)
  end)

  if os.getenv("GNATTEST_TEST_MODE") then
    describe("type_test_result (private)", function()
      it("returns I for PASSED", function()
        assert.equals("I", runner.type_test_result("PASSED"))
      end)

      it("returns E for FAILED", function()
        assert.equals("E", runner.type_test_result("FAILED"))
      end)

      it("returns E for any non-PASSED string", function()
        assert.equals("E", runner.type_test_result("ERROR"))
      end)
    end)

    describe("prepare_qf_item (private)", function()
      it(
        "builds a quickfix entry replacing 'corresponding' placeholder",
        function()
          local test_info = {
            source = { name = "My_Proc" },
            test = { line = "10", column = "5", file = "test.adb" },
          }

          local item = runner.prepare_qf_item(
            "Pkg",
            test_info,
            "corresponding test line",
            "E"
          )

          assert.equals("/found/file.adb", item.filename)
          assert.equals(10, item.lnum)
          assert.equals(5, item.col)
          assert.equals("E", item.type)
          assert.matches("Pkg:My_Proc.*test line", item.text)
        end
      )

      it("notifies when test file is not found", function()
        utils_mock.find_file.returns(nil)
        local test_info = {
          source = { name = "My_Proc" },
          test = { line = "10", column = "5", file = "missing.adb" },
        }

        runner.prepare_qf_item("Pkg", test_info, "corresponding test")

        assert.stub(utils_mock.notify).was_called()
      end)
    end)

    describe("open_qf_list (private)", function()
      it("sets quickfix list title and opens copen", function()
        runner.open_qf_list()

        assert.stub(_G.vim.fn.setqflist).was_called()
        assert.stub(_G.vim.cmd).was_called_with("copen")
      end)
    end)

    describe("on_exit_tests (private)", function()
      it("notifies error when stderr present", function()
        mock_system_async()
        runner.run_test()

        runner.on_exit_tests({ stderr = "runtime error" })

        assert
          .stub(utils_mock.notify)
          .was_called_with("Error running tests: runtime error", vim.log.levels.ERROR)
      end)

      it("notifies warning when stdout is empty", function()
        mock_system_async()
        runner.run_test()

        runner.on_exit_tests({ stdout = "" })

        assert
          .stub(utils_mock.notify)
          .was_called_with("No tests were run", vim.log.levels.WARN)
      end)

      it("processes valid test output and opens qf list", function()
        mock_system_async()
        runner.run_test()

        xml_mock.get_test_from_src_file_line.returns("source.ads", "Pkg", {
          source = { name = "My_Proc" },
          test = { line = "10", column = "5", file = "test.adb" },
        })
        utils_mock.find_file.returns("/found/test.adb")

        runner.on_exit_tests({
          stdout = "source.ads:10:PASSED\n",
          stderr = "",
        })

        assert.stub(_G.vim.fn.setqflist).was_called()
        assert.stub(_G.vim.cmd).was_called_with("copen")
      end)

      it("does not open qf list when pending runs remain", function()
        mock_system_async()
        runner.run_test()
        runner.run_test() -- pending = 2

        xml_mock.get_test_from_src_file_line.returns("source.ads", "Pkg", {
          source = { name = "My_Proc" },
          test = { line = "10", column = "5", file = "test.adb" },
        })

        runner.on_exit_tests({
          stdout = "source.ads:10:PASSED\n",
          stderr = "",
        })

        -- pending = 2 - 1 = 1, so open_qf_list is NOT called
        assert.stub(_G.vim.fn.setqflist).was_not_called()
      end)
    end)
  end
end)
