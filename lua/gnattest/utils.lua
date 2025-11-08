local utils = {
  gnattest_pattern = "**/gnattest/",
}

utils.plugin_name = "GNATtest"

function utils.notify(msg, lvl)
  local title = utils.plugin_name .. " " .. lvl .. " message"
  if utils.is_loaded("notify") then
    require("notify")(msg, lvl, { title = title })
  else
    vim.api.nvim_echo({ { title .. ": " .. msg } }, true, { err = true })
  end
end

function utils.is_loaded(plugin_name)
  return pcall(require, plugin_name) -- will also load the package if it isn't loaded already
end

function utils.get_bufid()
  return vim.api.nvim_get_current_buf()
end

function utils.get_bufdir()
  return vim.fn.expand("%")
end

function utils.is_gnattest_file()
  return string.find(utils.get_bufdir(), "gnattest") ~= nil
end

function utils.get_lines(start_row, end_row)
  return vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, true)
end

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

function utils.get_all_comments(language)
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

return utils
