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
  if ada_ls ~= nil then
    local json_file = ada_ls.config.root_dir .. "/.als.json"
    local config = vim.fn.json_decode(vim.fn.readfile(json_file))

    vim.cmd("!gnattest -P " .. config.projectFile)
  end
end

local function build_tests()
  vim.cmd("!gprbuild -P " .. require("gnattest.utils").get_gnattest_project())
end

local function run_all_tests()
  vim.cmd("!" .. require("gnattest.ada_ls").get_harness_dir() .. "/test_runner")
end

local function run_test(filename, lnum)
  if filename == nil or lnum == nil then
    return
  end

  vim.cmd(
    "!"
      .. require("gnattest.ada_ls").get_harness_dir()
      .. "/test_runner"
      .. " --routines="
      .. filename
      .. ":"
      .. lnum
  )
end

local function switch_source_test()
  require("gnattest.navigation").switch_subprogram()
end

local function impl_run(args)
  local str_args = vim.split(args[1], ":")
  local pkg = str_args[1]
  local name = str_args[2]
  local pkg_info, filename =
    require("gnattest.xml").get_tests_by_name(pkg, name)
  if pkg_info == nil then
    return
  end
  run_test(filename, pkg_info.source.line)
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
      build_tests()
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
      run_all_tests()
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
  nargs = "+",
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

-- vim.api.nvim_create_user_command("TSTest", function()
--   vim.cmd(":Lazy reload gnattest.nvim")
--   local ada = require("gnattest.ada_ls")
--   -- local xml = require("gnattest.xml")
--   -- local nav = require("gnattest.navigation")
--   local res = ada.get_src_dirs()
--   -- local res = nav.switch_subprogram()
--   -- local res = xml.get_subprogram_name()
--   -- local res = xml.get_declaration()
--   -- local res = xml.get_gnattest_info_on_cursor()
--   -- local res = xml.get_xml_info()
--   -- print(vim.inspect(xml.get_tests_by_name("Board", "Init")))
--   print(vim.inspect(res))
-- end, {})
