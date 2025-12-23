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

return M
