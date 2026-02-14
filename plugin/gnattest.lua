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
  local res = true
  vim.system(
    { "gprbuild", "-P" .. require("gnattest.utils").get_gnattest_project() },
    { text = true },
    function(obj)
      if obj.stderr and obj.stderr ~= "" then
        res = false
        print("Error building tests: " .. obj.stderr)
      else
        print("Tests built successfully.")
      end
    end
  )
  return res
end

local function prepare_run()
  if build_tests() then
    vim.fn.setqflist({}, "r") -- Clear the quickfix list before adding new items
    return true
  end
  return false
end

local function type_test_result(res)
  if res:find("PASSED") then
    return "I"
  else
    return "E"
  end
end

local function prepare_qf_item(test_info, line, type)
  local als = require("gnattest.ada_ls")
  local utils = require("gnattest.utils")

  local test_dir = als.get_tests_dir()
  local file = utils.find_file(test_info.test.file, test_dir)
  local lnum = test_info.test.line
  local col = test_info.test.column

  return {
    bufnr = 0,
    filename = file,
    lnum = lnum,
    col = col,
    text = line,
    type = type or "E",
  }
end

local function on_exit_tests(obj)
  if obj.stderr and obj.stderr ~= "" then
    print("Error running tests: " .. obj.stderr)
    return
  end

  local stdout = obj.stdout or ""
  if stdout == "" then
    print("No tests were run.")
    return
  end

  vim.schedule(function()
    local lines = vim.split(stdout, "\n")
    local items = {}

    for _, line in ipairs(lines) do
      local test_info = require("gnattest.xml").get_test_from_file_line(
        vim.split(line, ":")[1], -- filename
        tonumber(vim.split(line, ":")[2]) -- line number
      )
      if test_info ~= nil then
        table.insert(
          items,
          prepare_qf_item(test_info, tostring(line), type_test_result(line))
        )
      end
    end

    vim.fn.setqflist({}, "a", { title = "Gnattest run_all", items = items })
    vim.cmd("copen")
  end)
end

local function run_test(filename, lnum)
  local arg = ""
  if filename ~= nil and lnum ~= nil then
    arg = "--routines=" .. filename .. ":" .. lnum
  end

  local als = require("gnattest.ada_ls")
  vim.system({
    als.get_harness_dir() .. "/test_runner",
    arg,
  }, { text = true }, on_exit_tests)
end

local function run_all_tests()
  if prepare_run() then
    run_test(nil, nil)
  end
end

local function switch_source_test()
  require("gnattest.navigation").switch_subprogram()
end

local function impl_run(args)
  local str_args = vim.split(args[1], ":")
  local pkg = str_args[1]
  local name = str_args[2]
  local pkg_info, filename

  if name then
    local test_info
    test_info, filename = require("gnattest.xml").get_test_by_name(pkg, name)
    pkg_info = { test_info }
  else
    pkg_info, filename = require("gnattest.xml").get_pkg_tests(pkg)
  end

  if pkg_info == nil or next(pkg_info) == nil or filename == nil then
    return
  end

  if not prepare_run() then
    return
  end
  for _, info in pairs(pkg_info) do
    run_test(filename, info.source.line)
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
