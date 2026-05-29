local stub = require("luassert.stub")
local common = require("spec.helpers.common")

describe("gnattest.picker", function()
  local runner_mock
  local xml_mock
  local captured_finder_opts
  local captured_select_handler

  before_each(function()
    package.loaded["gnattest.picker"] = nil
    package.loaded["gnattest.runner"] = nil
    package.loaded["gnattest.xml"] = nil
    package.loaded["gnattest.ada_ls"] = nil
    package.loaded["gnattest.utils"] = nil

    captured_finder_opts = {}
    captured_select_handler = nil

    -- Telescope mocks
    package.preload["telescope"] = function()
      return {}
    end
    package.preload["telescope.pickers"] = function()
      return {
        new = function(_, opts)
          if opts.attach_mappings then
            opts.attach_mappings(1)
          end
          return {
            find = function()
              captured_finder_opts = opts.finder
            end,
          }
        end,
      }
    end
    package.preload["telescope.finders"] = function()
      return {
        new_table = function(opts)
          return opts
        end,
      }
    end
    package.preload["telescope.config"] = function()
      return {
        values = {
          generic_sorter = function()
            return {}
          end,
          grep_previewer = function()
            return {}
          end,
        },
      }
    end
    package.preload["telescope.actions"] = function()
      return {
        close = stub.new(),
        select_default = {
          replace = function(_, handler)
            captured_select_handler = handler
          end,
        },
      }
    end
    package.preload["telescope.actions.state"] = function()
      return {}
    end

    -- GNATtest module mocks
    runner_mock = {
      prepare_run = stub.new().returns(true),
      run_test = stub.new(),
    }
    package.loaded["gnattest.runner"] = runner_mock

    xml_mock = {
      get_xml_info = stub.new().returns({
        ["source.ads"] = {
          PkgA = {
            {
              source = { name = "Init", line = "10", column = "5" },
              tests = { { file = "test_a.adb", line = "15", column = "3" } },
            },
            {
              source = { name = "Read", line = "20", column = "5" },
              tests = { { file = "test_a.adb", line = "25", column = "3" } },
            },
          },
          PkgB = {
            {
              source = { name = "Write", line = "30", column = "5" },
              tests = { { file = "test_b.adb", line = "35", column = "3" } },
            },
          },
        },
      }),
    }
    package.loaded["gnattest.xml"] = xml_mock

    package.loaded["gnattest.ada_ls"] = {
      get_tests_dir = stub.new().returns("/test/dir"),
    }

    package.loaded["gnattest.utils"] = {
      try_require = stub.new().returns(true),
      notify = stub.new(),
    }

    _G.vim = _G.vim or {}
    _G.vim.log = {
      levels = { WARN = 3, ERROR = 4 },
    }
    _G.vim.notify = stub.new()
  end)

  after_each(function()
    package.preload["telescope"] = nil
    package.preload["telescope.pickers"] = nil
    package.preload["telescope.finders"] = nil
    package.preload["telescope.config"] = nil
    package.preload["telescope.actions"] = nil
    package.preload["telescope.actions.state"] = nil
    package.loaded["telescope"] = nil
    package.loaded["telescope.pickers"] = nil
    package.loaded["telescope.finders"] = nil
    package.loaded["telescope.config"] = nil
    package.loaded["telescope.actions"] = nil
    package.loaded["telescope.actions.state"] = nil
    common.cleanup_packages()
    package.loaded["gnattest.picker"] = nil
    package.loaded["gnattest.runner"] = nil
    package.loaded["gnattest.xml"] = nil
    package.loaded["gnattest.ada_ls"] = nil
  end)

  describe("select_tests()", function()
    it("populates picker with all project tests", function()
      require("gnattest.picker").select_tests()

      assert.is_not_nil(captured_finder_opts.results)
      assert.equals(3, #captured_finder_opts.results)

      local displays = {}
      for _, entry in ipairs(captured_finder_opts.results) do
        table.insert(displays, entry.display)
      end
      table.sort(displays)
      assert.same({ "PkgA:Init", "PkgA:Read", "PkgB:Write" }, displays)
    end)

    it("sets path and lnum from test info", function()
      require("gnattest.picker").select_tests()

      for _, entry in ipairs(captured_finder_opts.results) do
        if entry.display == "PkgA:Init" then
          assert.equals("/test/dir/test_a.adb", entry.path)
          assert.equals(20, entry.lnum)
          return
        end
      end
      error("Expected entry PkgA:Init not found")
    end)

    it("returns early when no tests in xml", function()
      xml_mock.get_xml_info.returns({})

      -- Should not error when tests_info is empty
      assert.has.no_errors(function()
        require("gnattest.picker").select_tests()
      end)
    end)

    it("returns early when telescope is not available", function()
      package.loaded["gnattest.utils"] = {
        try_require = stub.new().returns(false),
        notify = stub.new(),
      }
      package.loaded["gnattest.picker"] = nil

      require("gnattest.picker").select_tests()

      local utils = package.loaded["gnattest.utils"]
      assert.stub(utils.notify).was_called()
    end)
  end)

  describe("confirm handler", function()
    it("runs selected tests on confirm", function()
      require("gnattest.picker").select_tests()

      local action_state = require("telescope.actions.state")
      action_state.get_current_picker = function()
        return {
          get_multi_selection = function()
            return {
              { value = { filename = "source.ads", source_line = 10 } },
              { value = { filename = "source.ads", source_line = 20 } },
            }
          end,
        }
      end
      action_state.get_selected_entry = function()
        return nil
      end

      captured_select_handler()

      assert.stub(runner_mock.prepare_run).was_called()
      assert.stub(runner_mock.run_test).was_called_with("source.ads", 10)
      assert.stub(runner_mock.run_test).was_called_with("source.ads", 20)
    end)

    it("falls back to current entry when no multi-selection", function()
      require("gnattest.picker").select_tests()

      local action_state = require("telescope.actions.state")
      action_state.get_current_picker = function()
        return {
          get_multi_selection = function()
            return {}
          end,
        }
      end
      action_state.get_selected_entry = function()
        return { value = { filename = "source.ads", source_line = 30 } }
      end

      captured_select_handler()

      assert.stub(runner_mock.prepare_run).was_called()
      assert.stub(runner_mock.run_test).was_called_with("source.ads", 30)
    end)

    it("notifies warning when nothing selected", function()
      require("gnattest.picker").select_tests()

      local action_state = require("telescope.actions.state")
      action_state.get_current_picker = function()
        return {
          get_multi_selection = function()
            return {}
          end,
        }
      end
      action_state.get_selected_entry = function()
        return nil
      end

      captured_select_handler()

      assert.stub(package.loaded["gnattest.utils"].notify).was_called()
    end)

    it("does not run tests when prepare_run returns false", function()
      runner_mock.prepare_run.returns(false)
      require("gnattest.picker").select_tests()

      local action_state = require("telescope.actions.state")
      action_state.get_current_picker = function()
        return {
          get_multi_selection = function()
            return {
              { value = { filename = "source.ads", source_line = 10 } },
            }
          end,
        }
      end
      action_state.get_selected_entry = function()
        return nil
      end

      captured_select_handler()

      assert.stub(runner_mock.run_test).was_not_called()
    end)
  end)
end)
