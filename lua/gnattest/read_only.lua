local M = {
  namespace = vim.api.nvim_create_namespace("read_only"),
  ro_group = vim.api.nvim_create_augroup("read_only", { clear = true }),
  hl_group = "hl_ro",
  extmark = {},
  backup = nil,
  opt = {},
  region_text = {
    start = "begin read only",
    ending = "end read only",
  },
}

local comments = {}
local protect_flag = false

local function parse_comment(comment)
  -- Remove common comment prefixes to get to the actual content
  local content = comment.text:gsub('^[%-%/%#%"%;%%]+%s*', "")

  -- Check for region markers
  local start_region = content:match("^" .. M.region_text.start .. "%s*(.*)")
  if start_region then
    return {
      type = "start",
      line = comment.line,
    }
  elseif content:match("^" .. M.region_text.ending .. "%s*") then
    return {
      type = "end",
      line = comment.line,
    }
  end
  return nil
end

local function clear_extmarks()
  local bufid = require("gnattest.utils").get_bufid()
  vim.api.nvim_buf_clear_namespace(
    require("gnattest.utils").get_bufid(),
    M.namespace,
    bufid,
    -1
  )
  M.extmark = {}
end

local function clear()
  clear_extmarks()
  comments = {}
  protect_flag = false
  M.backup = nil
end

-- Use mark_id to update an extmark
local function set_extmark(start_row, end_row, mark_id)
  local opt = {
    end_row = end_row + 1,
    hl_eol = true,
    hl_group = M.hl_group,
    virt_text = { { "🔒", M.hl_group } },
    virt_text_pos = "overlay",
  }

  if mark_id ~= 0 then
    opt.id = mark_id
  end

  mark_id = vim.api.nvim_buf_set_extmark(
    require("gnattest.utils").get_bufid(),
    M.namespace,
    start_row,
    0,
    opt
  )

  M.extmark[mark_id] = {
    lines = require("gnattest.utils").get_lines(start_row, end_row),
    start_row = start_row,
    end_row = end_row,
  }
end

-- Calls `cb(start_line, end_line, index)` for each detected region.
-- `cb` should be a function accepting (start_line, end_line, index) parameters.
local function get_regions(cb)
  local region = nil
  local idx = 0

  for _, comment in ipairs(comments) do
    local marker = parse_comment(comment)
    if marker then
      if marker.type == "start" then
        region = { start = marker.line }
      elseif marker.type == "end" and region then
        region.ending = marker.line
        idx = idx + 1
        cb(region.start, region.ending, idx)
        region = nil
      end
    end
  end

  if M.backup == nil then
    M.backup = vim.deepcopy(M.extmark)
  end
end

local function protected_region_notif()
  protect_flag = true
  require("gnattest.utils").notify(
    "This is a read only region!",
    vim.log.levels.ERROR
  )
end

local function prepare_gnattest()
  M.opt = require("gnattest.config").get().read_only
  if M.opt.enabled == false then
    clear()
    return
  end

  comments = require("gnattest.utils").get_all_comments("ada")
  get_regions(set_extmark)
  require("gnattest.highlight").set_highlight(M.namespace, M.hl_group)
end

local function restore_lines(start, end_row, lines)
  vim.api.nvim_buf_set_lines(0, start, end_row, true, lines)
end

local function fix_ro_regions()
  if vim.opt.diff:get() then
    return
  end

  vim.schedule(function()
    M.opt = require("gnattest.config").get().read_only
    if M.opt.enabled == false then
      clear()
      return
    end

    local cursor_pos = vim.fn.getpos(".")
    local lnum = cursor_pos[2]
    local cnum = cursor_pos[3]

    local marks_to_restore = {}

    local all_marks = vim.api.nvim_buf_get_extmarks(
      require("gnattest.utils").get_bufid(),
      M.namespace,
      0,
      -1,
      { details = true, overlap = true }
    )

    for _, mark in ipairs(all_marks) do
      local mark_id = mark[1]
      local start_row = mark[2]
      local end_row = mark[4].end_row

      if end_row ~= nil then
        local lines =
          require("gnattest.utils").get_lines(start_row, end_row - 1)
        if not vim.deep_equal(lines, M.extmark[mark_id].lines) then
          table.insert(marks_to_restore, {
            start_row = start_row,
            end_row = end_row,
            id = mark_id,
          })
        end
      end
    end
    if #marks_to_restore > 0 then
      for _, mark in ipairs(marks_to_restore) do
        local mark_id = mark.id
        protected_region_notif()
        vim.cmd([[stopinsert]])
        restore_lines(mark.start_row, mark.end_row, M.extmark[mark_id].lines)
        set_extmark(
          M.extmark[mark_id].start_row,
          M.extmark[mark_id].end_row,
          mark_id
        )
        -- reset cursor position
        vim.api.nvim_win_set_cursor(0, { lnum, cnum })
      end
    end
  end)
end

local function refresh()
  clear()
  prepare_gnattest()
end

local function conform_workaround()
  local is_ro_enabled = require("gnattest.config").get().read_only.enabled
  if is_ro_enabled == false then
    return
  end

  vim.api.nvim_create_autocmd("User", {
    group = M.ro_group,
    pattern = "ConformFormatPre",
    callback = function()
      is_ro_enabled = require("gnattest.config").get().read_only.enabled
      -- This is a workaround for conform.nvim, which doesn't trigger TextChanged events during formatting.
      -- By refreshing the read-only regions before formatting, we ensure that any changes made by the formatter
      -- are correctly handled and that the read-only regions are properly protected.
      ---@diagnostic disable-next-line: missing-fields
      require("gnattest.config").set({ read_only = { enabled = false } })
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = M.ro_group,
    pattern = "ConformFormatPost",
    callback = function()
      if is_ro_enabled == false then
        return
      end
      -- After formatting is done, we need to fix the read-only regions again to ensure that any changes made by the formatter
      -- are correctly handled and that the read-only regions are properly protected.
      ---@diagnostic disable-next-line: missing-fields
      require("gnattest.config").set({ read_only = { enabled = true } })
      vim.schedule(refresh)
    end,
  })
end

function M.setup()
  M.opt = require("gnattest.config").get().read_only

  if M.opt.enabled == false then
    return
  end

  local gnattest_pattern = require("gnattest.utils").gnattest_pattern

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = M.ro_group,
    callback = function()
      require("gnattest.highlight").set_highlight(M.namespace, M.hl_group)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter", "BufEnter" }, {
    group = M.ro_group,
    pattern = gnattest_pattern,
    callback = function()
      refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = M.ro_group,
    pattern = gnattest_pattern,
    callback = function()
      if protect_flag then
        protect_flag = false
        prepare_gnattest()
        return
      end
      fix_ro_regions()
    end,
  })

  conform_workaround()
end

function M.reset()
  refresh()
  M.setup()
end

-- Test-specific exports - only exposed in test mode
if os.getenv("GNATTEST_TEST_MODE") then
  M._parse_comment = parse_comment
  M._get_regions = get_regions
  M._set_extmark = set_extmark
  M._fix_ro_regions = fix_ro_regions
end

return M
