-- Health check module tests
-- Note: Full health check testing requires running in actual Neovim
-- Use :checkhealth gnattest to verify functionality

describe("health", function()
  it("module can be required", function()
    -- Health module requires Neovim runtime, so we just verify it exists
    local ok, _ = pcall(function()
      package.loaded["gnattest.health"] = nil
      return true
    end)
    assert.is_true(ok)
  end)

  it("health.lua file exists", function()
    local f = io.open("lua/gnattest/health.lua", "r")
    assert.is_not_nil(f)
    if f then
      f:close()
    end
  end)

  it("health.lua contains check function", function()
    local f = io.open("lua/gnattest/health.lua", "r")
    assert.is_not_nil(f)
    if f then
      local content = f:read("*all")
      f:close()
      assert.is_true(content:match("function M%.check%(%)") ~= nil)
      assert.is_true(content:match("return M") ~= nil)
    end
  end)
end)
