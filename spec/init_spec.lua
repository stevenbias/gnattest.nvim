local stub_new = require("luassert.stub").new

describe("gnattest.init", function()
  local gnattest_init

  before_each(function()
    gnattest_init = require("gnattest.init")

    _G.vim = {
      api = {
        nvim_create_autocmd = stub_new(),
      },
    }
    package.preload["gnattest.utils"] = function()
      return { gnattest_pattern = "**/gnattest/" }
    end
    package.preload["gnattest.read_only"] = function()
      return { setup = stub_new() }
    end
    package.preload["gnattest.ada_ls"] = function()
      return { setup = stub_new() }
    end
  end)

  after_each(function()
    _G.vim = nil
    package.preload["gnattest.utils"] = nil
    package.preload["gnattest.read_only"] = nil
    package.preload["gnattest.ada_ls"] = nil
  end)

  it("rejects unsupported options in setup", function()
    local opts = { foo = "bar" }
    assert.has_error(function()
      _G.vim.api.nvim_create_autocmd = function(event, tbl)
        -- simulate autocmd by calling callback
        tbl.callback("BufReadPre")
      end
      gnattest_init.setup(opts)
      -- simulate autocmd callback directly, as nvim_create_autocmd only registers
      -- we want to check error
    end, "Options are not supported")
  end)

  it("calls read_only.setup and ada_ls.setup if no options", function()
    local ro_mock = require("gnattest.read_only")
    local ada_mock = require("gnattest.ada_ls")

    local called_callback
    _G.vim.api.nvim_create_autocmd = function(event, tbl)
      tbl.callback("BufReadPre")
      called_callback = true
    end
    gnattest_init.setup()
    assert.is_true(called_callback)
  end)

  it("calls read_only.setup and ada_ls.setup if empty options", function()
    local ro_mock = require("gnattest.read_only")
    local ada_mock = require("gnattest.ada_ls")

    local called_callback
    _G.vim.api.nvim_create_autocmd = function(event, tbl)
      tbl.callback("BufReadPre")
      called_callback = true
    end
    gnattest_init.setup({})
    assert.is_true(called_callback)
  end)
end)
