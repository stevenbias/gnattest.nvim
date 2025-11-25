-- tests/unit/ada_ls_spec.lua
describe("gnattest.ada_ls", function()
  local ada_ls = require("gnattest.ada_ls")

  it("should return nil if no ALS is active", function()
    -- Mock vim.lsp.get_active_clients to return empty table
    _G.vim = _G.vim or {}
    _G.vim.lsp = {
      get_clients = function()
        return {}
      end,
    }
    assert.is_nil(ada_ls.get_ada_ls())
  end)
end)
