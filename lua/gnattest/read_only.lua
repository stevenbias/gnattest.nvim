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
local nb_regions = 0

local function get_parser()
  local buf = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "ada")

  if ok then
    return parser
  end
  return nil
end

-- Get the root node of the syntax tree
local function get_root()
  local parser = get_parser()
  if not parser then
    return nil
  end
  return parser:parse()[1]:root()
end

local function parse_comment(comment, opt)
  -- Remove common comment prefixes to get to the actual content
  local content = comment.text:gsub('^[%-%/%#%"%;%%]+%s*', "")

  -- Check for region markers
  local start_region = content:match("^" .. opt.region_text.start .. "%s*(.*)")
  if start_region then
    return {
      type = "start",
      title = #start_region > 0 and start_region or nil,
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

local function get_all_comments()
  local root = get_root()
  if not root then
    return {}
  end

  local cmts = {}
  local query_string = "(comment) @comment"
  local ok, query = pcall(vim.treesitter.query.parse, "ada", query_string)

  if not ok or not query then
    return {}
  end

  for id, node in query:iter_captures(root, 0) do
    if query.captures[id] == "comment" then
      local start_row = node:range()
      local text = vim.treesitter.get_node_text(node, 0)
      table.insert(cmts, {
        node = node,
        text = text:gsub("^%s*", ""):gsub("%s*$", ""), -- Trim whitespace
        line = start_row + 1, -- Convert to 1-based line number
      })
    end
  end
  return cmts
end

local function get_regions()
  local regions_found = {}
  local current_region = nil

  for _, comment in ipairs(comments) do
    local marker = parse_comment(comment, M.opt)
    if marker then
      if marker.type == "start" then
        current_region = {
          start = marker.line,
          title = marker.title,
        }
      elseif marker.type == "end" and current_region then
        current_region.ending = marker.line
        table.insert(regions_found, current_region)
        current_region = nil
      end
    end
  end
  return regions_found
end

local function fix_ro_region()
  local utils = require("gnattest.utils")
  protect_flag = true
  vim.cmd([[stopinsert]])
  vim.cmd("undo")
  utils.notify("This is a read only region!", "error")
end

local function protect_ro_regions()
  if vim.opt.diff:get() then
    return
  end

  vim.schedule(function()
    local lnum = vim.fn.getpos(".")[2]
    if #regions ~= nb_regions then
      fix_ro_region()
      return
    end
    for _, region in ipairs(regions) do
      if lnum > region.start and lnum <= region.ending then
        fix_ro_region()
        return
      end
    end
  end)
end

local function set_extmark(start_line, end_line)
  local utils = require("gnattest.utils")
  vim.api.nvim_buf_set_extmark(
    utils.get_bufid(),
    M.namespace,
    start_line - 1,
    0,
    { end_row = end_line, hl_eol = true, hl_group = M.hl_group }
  )
end

local function highlight_regions()
  for _, region in ipairs(regions) do
    set_extmark(region.start, region.ending)
  end
  hl.set_highlight(M.namespace, M.hl_group)
end

local function prepare_gnattest()
  comments = get_all_comments()
  regions = get_regions()
  highlight_regions()
end

function M.setup(opt)
  M.opt = opt

  local utils = require("gnattest.utils")

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = M.ro_group,
    callback = function()
      hl.set_highlight(M.namespace, M.hl_group)
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = M.ro_group,
    pattern = {
      utils.gnattest_pattern .. "*.adb",
      utils.gnattest_pattern .. "*.ads",
    },
    callback = function()
      prepare_gnattest()

      if #regions <= 0 then
        return
      end

      nb_regions = #regions

      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = M.ro_group,
        pattern = {
          utils.gnattest_pattern .. "*.adb",
          utils.gnattest_pattern .. "*.ads",
        },
        callback = function()
          if protect_flag then
            protect_flag = false
            return
          end
          protect_ro_regions()
          prepare_gnattest()
        end,
      })
    end,
  })
end

return M
