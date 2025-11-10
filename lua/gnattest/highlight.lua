local M = {}

-- Helper function to convert a Hex string (#RRGGBB) to an RGB table {r, g, b}
local function hex_to_rgb(hex)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  return { r, g, b }
end

-- Helper function to convert an RGB table {r, g, b} back to a Hex string
local function rgb_to_hex(rgb)
  local hex = string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
  return hex
end

--- Function to lighten or darken a hex color
--- @param hex string The hex color string (e.g., '#1a1a1a')
--- @param percent number The percentage to change (e.g., 20 for lighter, -20 for darker)
--- @return string The modified hex color string
local function modify_color(hex, percent)
  local rgb = hex_to_rgb(hex)
  local amount = math.floor(255 * (percent / 100))

  -- Apply the adjustment and clamp the value between 0 and 255
  local new_rgb = {
    math.min(255, math.max(0, rgb[1] + amount)),
    math.min(255, math.max(0, rgb[2] + amount)),
    math.min(255, math.max(0, rgb[3] + amount)),
  }

  return rgb_to_hex(new_rgb)
end

local function get_hl()
  local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if hl and hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

function M.set_highlight(namespace, hl_group)
  local hl = get_hl()
  local new_bg = "#303030"

  local percent = 3

  if vim.o.background == "light" then
    percent = -percent
  end

  if hl ~= nil then
    new_bg = modify_color(hl, percent)
  end

  vim.api.nvim_set_hl(namespace, hl_group, { bg = new_bg, force = true })
  vim.api.nvim_set_hl_ns(namespace)
end

function M.setup(opt)
  M.opt = opt
end

return M
