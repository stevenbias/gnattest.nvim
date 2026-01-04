local M = {}

-- Creates a basic vim API mock with common functions
function M.create_basic_vim_mock()
  -- Preserve existing vim if it exists (for nlua runtime)
  local existing_vim = _G.vim or {}

  local mock = {
    api = existing_vim.api or {},
    fn = existing_vim.fn or {},
    cmd = existing_vim.cmd or function() end,
    schedule = existing_vim.schedule or function(fn)
      fn()
    end,
  }

  -- Add our mock functions
  mock.api.nvim_create_autocmd = mock.api.nvim_create_autocmd or function() end
  mock.api.nvim_create_augroup = mock.api.nvim_create_augroup
    or function()
      return 1
    end
  mock.api.nvim_clear_autocmds = mock.api.nvim_clear_autocmds or function() end
  mock.api.nvim_buf_set_option = mock.api.nvim_buf_set_option or function() end
  mock.api.nvim_win_get_buf = mock.api.nvim_win_get_buf
    or function()
      return 1
    end
  mock.api.nvim_get_current_buf = mock.api.nvim_get_current_buf
    or function()
      return 1
    end
  mock.api.nvim_buf_get_name = mock.api.nvim_buf_get_name
    or function()
      return "test.adb"
    end
  mock.api.nvim_command = mock.api.nvim_command or function() end
  mock.api.nvim_feedkeys = mock.api.nvim_feedkeys or function() end
  mock.api.nvim__get_runtime = mock.api.nvim__get_runtime
    or function()
      return {}
    end

  mock.fn.expand = mock.fn.expand or function()
    return "test.adb"
  end
  mock.fn.filereadable = mock.fn.filereadable or function()
    return 1
  end

  return mock
end

-- Creates a mock that captures autocmd calls for testing
function M.create_autocmd_capture_mock()
  local autocmds = {}
  local vim_mock = M.create_basic_vim_mock()

  vim_mock.api.nvim_create_autocmd = function(events, opts)
    table.insert(autocmds, { events = events, opts = opts })
  end

  return vim_mock, autocmds
end

return M
