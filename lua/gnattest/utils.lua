local M = {
  gnattest_pattern = "**/gnattest/",
}

M.plugin_name = "GNATtest"

local function log_lvl_tostring(lvl)
  if lvl == 0 then
    return "TRACE"
  elseif lvl == 1 then
    return "DEBUG"
  elseif lvl == 2 then
    return "INFO"
  elseif lvl == 3 then
    return "WARN"
  elseif lvl == 4 then
    return "ERROR"
  elseif lvl == 5 then
    return "OFF"
  else
    return "ERROR"
  end
end

function M.notify(msg, lvl)
  local title = M.plugin_name .. " " .. log_lvl_tostring(lvl) .. " message"
  if M.is_loaded("notify") then
    require("notify")(msg, lvl, { title = title })
  else
    vim.notify(title .. ": " .. msg, lvl)
  end
end

function M.is_loaded(plugin_name)
  return pcall(require, plugin_name) -- will also load the package if it isn't loaded already
end

function M.get_bufid()
  return vim.api.nvim_get_current_buf()
end

function M.get_bufpath()
  return vim.fn.expand("%")
end

function M.get_filename()
  return vim.fs.basename(M.get_bufpath())
end

function M.get_bufdir()
  return vim.fs.dirname(M.get_bufpath())
end

function M.is_gnattest_file()
  return string.find(M.get_bufdir(), "gnattest") ~= nil
end

function M.get_lines(start_row, end_row)
  return vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, true)
end

function M.find_file(filename, path)
  if vim.islist(path) then
    for _, p in pairs(path) do
      local file = vim.fs.find({ filename }, { type = "file", path = p })
      if next(file) ~= nil then
        return file[1]
      end
    end
  else
    return vim.fs.find({ filename }, { type = "file", path = path })[1]
  end
end

local function get_parser()
  local buf = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "ada")

  if ok then
    return parser
  elseif not ok or not parser then
    vim.notify(
      "GNATtest: Ada treesitter parser missing, skipping syntax analysis",
      vim.log.levels.WARN
    )
    return nil
  end
end

-- Get the root node of the syntax tree
local function get_root()
  local parser = get_parser()
  if not parser then
    return nil
  end
  return parser:parse()[1]:root()
end

function M.get_all_comments(language)
  local root = get_root()
  if not root then
    return {}
  end

  local cmts = {}
  local query_string = "(comment) @comment"
  local ok, query = pcall(vim.treesitter.query.parse, language, query_string)

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
        line = start_row,
      })
    end
  end
  return cmts
end

return M
