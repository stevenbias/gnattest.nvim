-- local stub = require("luassert.stub")

describe("gnattest.utils", function()
  local utils

  before_each(function()
    -- Stub basic Neovim API functions used in utils.lua
    _G.vim = _G.vim or {}
    _G.vim.api = {
      nvim_get_current_buf = function()
        return 0
      end,
      -- nvim_buf_get_lines = function(_, start_row, end_row_plus1, _)
      --   return { "line1", "line2" }
      -- end,
      nvim__get_runtime = function()
        return {}
      end,
    }
    _G.vim.fn = {
      expand = function(_)
        return "gnattest/gnattest_file.adb"
      end,
    }
    -- Stub Treesitter as used by utils.lua
    _G.vim.treesitter = {
      get_parser = function(_, lang)
        if lang == "ada" then
          return {
            parse = function()
              -- mimic parse tree with root
              return {
                {
                  root = function()
                    return 99
                  end,
                },
              }
            end,
          }
        end
        error("No parser")
      end,
      query = {
        -- parse = function(lang, query_str)
        --   return {
        --     iter_captures = function(root, bufnr)
        --       local node = {
        --         range = function()
        --           return 10
        --         end, -- let range return something
        --       }
        --       local id = 1
        --       return coroutine.wrap(function()
        --         coroutine.yield(id, node)
        --       end)
        --     end,
        --     captures = { "comment" },
        --   }
        -- end,
      },
      get_node_text = function(_, _)
        -- Always return a comment text string for tests
        return "--begin read only"
      end,
    }
    -- Stub vim.fs if used anywhere by utils.lua or its dependencies
    _G.vim.fs = {
      find = function(_)
        return {}
      end,
      dirname = function(_)
        return "gnattest"
      end,
    }
    -- Stub notify plugin and vim.notify
    package.loaded["notify"] = nil
    -- vim.notify = stub.new()

    _G.original_require = _G.require
    -- Remplace require pour retourner le mock
    _G.require = function(modname)
      if modname == "notify" then
        return vim.api.nvim_echo
      else
        return _G.original_require(modname)
      end
    end

    -- Only load utils **after** all necessary stubs
    local ok, err = pcall(function()
      require("gnattest.utils")
    end)
    print(ok, err)

    utils = require("gnattest.utils")
  end)

  after_each(function()
    package.loaded["gnattest.utils"] = nil
    _G.require = _G.original_require
  end)

  it("notifies using nvim_echo when notify not loaded", function()
    utils.is_loaded = function()
      return false
    end
    utils.notify("foo", "warn")
    assert.stub(vim.api.nvim_echo).was_called()
  end)

  it("notifies using vim.notify if present", function()
    utils.is_loaded = function()
      return false
    end
    utils.notify("bar", "info")
    assert.stub(vim.notify).was_called()
  end)

  it("returns current buffer id", function()
    assert.equals(0, utils.get_bufid())
  end)

  it("detects gnattest file path", function()
    assert.is_true(utils.is_gnattest_file())
  end)

  -- it("returns lines from get_lines", function()
  --   assert.are.same({ "line1", "line2" }, utils.get_lines(0, 1))
  -- end)
  --
  -- it("returns comments via get_all_comments", function()
  --   local comments = utils.get_all_comments("ada")
  --   assert.truthy(comments)
  --   assert.same("--begin read only", comments[1].text)
  -- end)
end)
