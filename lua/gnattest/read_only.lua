local hl = require("gnattest.highlight")

local M = {
  namespace = vim.api.nvim_create_namespace("read_only"),
  ro_group = vim.api.nvim_create_augroup("read_only", { clear = true }),
  hl_group = "hl_ro",
  opt = {},
}

local comments = {}
local regions = {}
local protect_flag = false
local function parse_comment(comment, opt)
  -- Remove common comment prefixes to get to the actual content
  local content = comment.text:gsub('^[%-%/%#%"%;%%]+%s*', "")

  -- Check for region markers
  local start_region = content:match("^" .. opt.region_text.start .. "%s*(.*)")
  if start_region then
    return {
      type = "start",
      line = comment.line,
    }
  elseif content:match("^" .. opt.region_text.ending .. "%s*") then
    return {
      type = "end",
      line = comment.line,
    }
  end
  return nil
end

local function set_extmark(start_line, end_line)
  return vim.api.nvim_buf_set_extmark(
    require("gnattest.utils").get_bufid(),
    M.namespace,
    start_line,
    0,
    {
      end_row = end_line + 1,
      hl_eol = true,
      hl_group = M.hl_group,
    }
  )
end

local function get_regions()
  local region = nil

  for _, comment in ipairs(comments) do
    local marker = parse_comment(comment, M.opt)
    if marker then
      if marker.type == "start" then
        region = {
          start = marker.line,
        }
      elseif marker.type == "end" and region then
        region.ending = marker.line
        local mark_id = set_extmark(region.start, region.ending)
        M.extmark_lines[mark_id] =
          require("gnattest.utils").get_lines(region.start, region.ending)
        region = nil
      end
    end
  end
end

local function fix_ro_region()
  local utils = require("gnattest.utils")
  protect_flag = true
  vim.cmd([[stopinsert]])
  vim.cmd("undo")
  utils.notify("This is a read only region!", "error")
end

local function highlight_regions()
  require("gnattest.highlight").set_highlight(M.namespace, M.hl_group)
end

local function prepare_gnattest()
  comments = require("gnattest.utils").get_all_comments("ada")
  get_regions()
  highlight_regions()
end

local function protect_ro_regions()
  if vim.opt.diff:get() then
    return
  end

  vim.schedule(function()
    local lnum = vim.fn.line(".") - 1

    local all_marks =
      vim.api.nvim_buf_get_extmarks(0, M.namespace, 0, -1, { details = true })
    -- require("gnattest.utils").notify(vim.inspect(all_marks), "INFO")

    for _, mark in ipairs(all_marks) do
      local mark_id = mark[1]
      local start_row = mark[2]
      local end_row = mark[4].end_row

      -- require("gnattest.utils").notify(start_row .. end_row, "INFO")
      if end_row == nil then
        return
      end

      if lnum >= start_row and lnum <= end_row then
        require("gnattest.utils").notify(vim.inspect(mark), "INFO")
        fix_ro_region()
        prepare_gnattest()
        return
      end
    end
  end)
end

function M.setup(opt)
  M.opt = opt

  local utils = require("gnattest.utils")

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = M.ro_group,
    callback = function()
      require("gnattest.highlight").set_highlight(M.namespace, M.hl_group)
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = M.ro_group,
    pattern = {
      utils.gnattest_pattern .. "*.ad[bs]",
    },
    callback = function()
      prepare_gnattest()

      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = M.ro_group,
        pattern = {
          utils.gnattest_pattern .. "*.ad[bs]",
        },
        callback = function()
          if protect_flag then
            protect_flag = false
            return
          end
          protect_ro_regions()
        end,
      })
    end,
  })
end

return M
