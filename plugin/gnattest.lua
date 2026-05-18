-- Define commands with subcommands, from: https://github.com/lumen-oss/nvim-best-practices?tab=readme-ov-file#speaking_head-user-commands

if vim.g.loaded_gnattest then
  return
end
vim.g.loaded_gnattest = true

local cmd_name = "Gnattest"

local function clean_tests()
  vim.cmd("!gprclean -P " .. require("gnattest.utils").get_gnattest_project())
end

local function generate_tests()
  local ada_ls = require("gnattest.ada_ls").get_ada_ls()
  local utils = require("gnattest.utils")

  if ada_ls ~= nil then
    local prj_file = require("gnattest.ada_ls").get_prj_file()

    local ro_config = require("gnattest.config").get().read_only
    local is_read_only_enabled = ro_config.enabled
    local disable_ro = is_read_only_enabled and utils.is_gnattest_file()
    if disable_ro then
      ---@diagnostic disable-next-line: missing-fields
      require("gnattest.config").set({ read_only = { enabled = false } })
    end

    local obj = vim
      .system({ "gnattest", "-P", prj_file }, { text = true })
      :wait()
    if obj.code ~= 0 then
      print("Error generating tests: Process exited with code " .. obj.code)
    else
      print("Tests generated successfully")
    end

    if disable_ro then
      ---@diagnostic disable-next-line: missing-fields
      require("gnattest.config").set({ read_only = { enabled = true } })
      require("gnattest.read_only").reset()
      vim.cmd.edit() -- Refresh the buffer to apply read-only regions after generating tests
    end

    require("gnattest.xml").get_xml_info(true) -- Refresh XML info after generating tests
  end
end

local function get_test_info_on_cursor()
  local f, _, info = require("gnattest.xml").get_gnattest_info_on_cursor()
  if f == nil or info == nil then
    require("gnattest.utils").notify(
      "No test information found at cursor",
      vim.log.levels.WARN
    )
    return
  end
  return f, info
end

local function switch_source_test()
  require("gnattest.navigation").switch_subprogram()
end

local function impl_run(arg1, arg2)
  local runner = require("gnattest.runner")
  if not runner.prepare_run() then
    return
  end

  if not arg1 or type(arg1) == "table" and not next(arg1) then
    runner.run_test() -- Run all tests
  elseif not arg2 then -- Run tests by package or package:test
    local str_args = vim.split(arg1[1], ":")
    local pkg = str_args[1]
    local name = str_args[2]
    local pkg_info, filename
    if name then
      local test_info
      test_info, filename = require("gnattest.xml").get_test_by_name(pkg, name)
      if test_info == nil then
        return
      end
      pkg_info = { test_info }
    else
      pkg_info, filename = require("gnattest.xml").get_pkg_tests(pkg)
    end

    if pkg_info == nil or next(pkg_info) == nil or filename == nil then
      return
    end
    for _, info in pairs(pkg_info) do
      runner.run_test(filename, info.source.line)
    end
  else -- Run tests by file and line
    local filename = arg1
    local lnum = tonumber(arg2)
    runner.run_test(filename, lnum)
  end
end

local function compl_run(subcmd_arg_lead)
  local tests_info = require("gnattest.xml").get_xml_info()
  local run_args = {}
  for _, files in pairs(tests_info) do
    for pkg, pkg_info in pairs(files) do
      for _, info in pairs(pkg_info) do
        table.insert(run_args, pkg .. ":" .. info.source.name)
      end
    end
  end
  return vim
    .iter(run_args)
    :filter(function(args)
      return args:find(subcmd_arg_lead) ~= nil
    end)
    :totable()
end

---@class MyCmdSubcommand
---@field impl fun(args:string[], opts: table) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments

---@type table<string, MyCmdSubcommand>
local subcommand_tbl = {
  clean = {
    impl = function()
      clean_tests()
    end,
  },
  build = {
    impl = function()
      require("gnattest.runner").build_tests()
    end,
  },
  generate = {
    impl = function()
      generate_tests()
    end,
  },
  run = {
    impl = function(args, _)
      impl_run(args)
    end,
    complete = function(arg)
      return compl_run(arg)
    end,
  },
  run_all = {
    impl = function()
      local msg =
        "'run_all' command will be deprecated in favor of 'run' with no arguments"
      require("gnattest.utils").notify(msg, vim.log.levels.WARN)
      impl_run()
    end,
  },
  run_cursor = {
    impl = function()
      local f, info = get_test_info_on_cursor()
      if f ~= nil and info ~= nil then
        impl_run(f, info.source.line)
      end
    end,
  },
  run_select = {
    impl = function()
      require("gnattest.picker").select_tests()
    end,
  },
  switch = {
    impl = function()
      switch_source_test()
    end,
  },
}

---@param opts table :h lua-guide-commands-create
local function subcmd(opts)
  local fargs = opts.fargs
  local subcommand_key = fargs[1]
  -- Get the subcommand's arguments, if any
  local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
  local subcommand = subcommand_tbl[subcommand_key]
  if not subcommand then
    vim.notify(
      cmd_name .. ": Unknown command: " .. subcommand_key,
      vim.log.levels.ERROR
    )
    return
  end
  -- Invoke the subcommand
  subcommand.impl(args, opts)
end

vim.api.nvim_create_user_command(cmd_name, subcmd, {
  nargs = "*",
  desc = cmd_name .. " commands",
  complete = function(arg_lead, cmdline, _)
    -- Get the subcommand.
    local subcmd_key, subcmd_arg_lead =
      cmdline:match("^['<,'>]*" .. cmd_name .. "[!]*%s(%S+)%s(.*)$")
    if
      subcmd_key
      and subcmd_arg_lead
      and subcommand_tbl[subcmd_key]
      and subcommand_tbl[subcmd_key].complete
    then
      -- The subcommand has completions. Return them.
      return subcommand_tbl[subcmd_key].complete(subcmd_arg_lead)
    end
    -- Check if cmdline is a subcommand
    if cmdline:match("^['<,'>]*" .. cmd_name .. "[!]*%s+%w*$") then
      -- Filter subcommands that match
      local subcommand_keys = vim.tbl_keys(subcommand_tbl)
      return vim
        .iter(subcommand_keys)
        :filter(function(key)
          return key:find(arg_lead) ~= nil
        end)
        :totable()
    end
  end,
  bang = true,
})
