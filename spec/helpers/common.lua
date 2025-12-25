-- Common test utilities - only patterns used 3+ times
local stub = require("luassert.stub")

local M = {}

-- Package management (used in 3+ files)
function M.mock_utils(overrides)
  local utils_mock = {
    notify = stub.new(),
    gnattest_pattern = "**/gnattest/",
    get_bufid = function()
      return 1
    end,
    get_bufpath = function()
      return "gnattest/test_file.adb"
    end,
    get_bufdir = function()
      return "/project/gnattest/harness"
    end,
    get_lines = function()
      return { "line1", "line2" }
    end,
  }
  if overrides then
    for k, v in pairs(overrides) do
      utils_mock[k] = v
    end
  end
  package.preload["gnattest.utils"] = function()
    return utils_mock
  end
end

function M.cleanup_packages()
  package.preload["gnattest.utils"] = nil
  package.loaded["gnattest.utils"] = nil
end

-- Vim API mocking (used in all 6 spec files)
function M.create_basic_vim_api(custom_api)
  local base_api = {
    nvim_echo = function(msg)
      return msg
    end,
    nvim_get_current_buf = function()
      return 1
    end,
    nvim_buf_get_lines = function()
      return {}
    end,
    nvim_buf_set_lines = stub.new(),
    nvim_get_hl = function()
      return {}
    end,
    nvim_set_hl = stub.new(),
    nvim_set_hl_ns = stub.new(),
    nvim_create_autocmd = stub.new(),
    nvim_create_namespace = function()
      return "test"
    end,
    nvim_create_augroup = function()
      return "test_augroup"
    end,
    nvim_create_buf = function()
      return 1
    end,
    nvim_buf_set_extmark = stub.new().returns(42),
    nvim_buf_get_extmarks = stub.new().returns({}),
  }

  if custom_api then
    for k, v in pairs(custom_api) do
      base_api[k] = v
    end
  end

  return base_api
end

-- Complete vim globals setup (handles more complex cases)
function M.setup_vim_globals(custom_api, custom_fn, custom_other)
  _G.vim = _G.vim or {}
  _G.vim.api = M.create_basic_vim_api(custom_api)
  _G.vim.fn = M.create_vim_fn_mock(custom_fn)

  if custom_other then
    for k, v in pairs(custom_other) do
      _G.vim[k] = v
    end
  end
end

-- Vim function mocking (used in 4 spec files)
function M.create_vim_fn_mock(overrides)
  local base_fn = {
    expand = function()
      return "/test/path"
    end,
    readfile = function()
      return {}
    end,
    getpos = function()
      return { 0, 5, 10 }
    end,
  }

  if overrides then
    for k, v in pairs(overrides) do
      base_fn[k] = v
    end
  end

  return base_fn
end

-- Private function testing helper (used in 3 spec files)
-- Returns true if private functions should be tested
function M.should_test_private_functions()
  return os.getenv("GNATTEST_TEST_MODE") ~= nil
end

return M
