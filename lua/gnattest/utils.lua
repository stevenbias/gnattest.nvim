local utils = {}

utils.plugin_name = "GNATtest"

function utils.notify(msg, lvl)
	local title = utils.plugin_name .. " " .. lvl .. " message"
	if utils.is_loaded("notify") then
		require("notify")(msg, lvl, { title = title })
	else
		vim.api.nvim_err_writeln(title .. ": " .. msg)
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

return utils
