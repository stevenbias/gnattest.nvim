-- Define commands with subcommands, from: https://github.com/lumen-oss/nvim-best-practices?tab=readme-ov-file#speaking_head-user-commands

local cmd_name = "GNATtest"
local test_project = "obj/gnattest/harness/test_driver.gpr"
local test_runner = "obj/gnattest/harness/test_runner"

local function clean_tests()
  vim.cmd("!gprclean -P " .. test_project)
end

local function build_tests()
  vim.cmd("!gprbuild -P " .. test_project)
end

local function run_tests()
  vim.cmd("!./" .. test_runner)
end

---@class MyCmdSubcommand
---@field impl fun(args:string[], opts: table) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] (optional) Command completions callback, taking the lead of the subcommand's arguments

---@type table<string, MyCmdSubcommand>
local subcommand_tbl = {
  Clean = {
    impl = function()
      clean_tests()
    end,
  },
  Build = {
    impl = function()
      build_tests()
    end,
  },
  Run = {
    impl = function()
      run_tests()
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
  desc = cmd_name .. "commands",
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

vim.api.nvim_create_user_command("TSTest", function()
  local tests = {}
  local source_files = {}

  --------------
  -- **UNIT** --
  --------------
  local query_unit_string = '\
    (element\
      (STag (Name) @tag (#eq? @tag "unit"))\
    )@element'

  local query_source_files =
    vim.treesitter.query.parse("xml", query_unit_string)

  local root = vim.treesitter.get_parser():parse()[1]:root()
  for i, node in query_source_files:iter_captures(root, 0) do
    ------------------
    -- **FILENAME** --
    ------------------
    if query_source_files.captures[i] == "element" then
      local text = vim.treesitter.get_node_text(node, 0)
      local query_file_string = '\
        (STag ((Attribute ((Name) @tag.attribute)\
                          (#eq? @tag.attribute "source_file")\
                          (AttValue) @source_file))\
        )'
      local query_files = vim.treesitter.query.parse("xml", query_file_string)
      local filename_node = node
      for _, n in query_files:iter_captures(filename_node, 0) do
        text = vim.treesitter.get_node_text(n, 0)
        if text ~= "source_file" then
          local filename = text:gsub('"', "")
          local subpr_test = {}
          source_files = {
            [filename] = {},
          }
          --------------------
          -- **SUBPROGRAM** --
          --------------------
          local query_subpr_string = '\
            (STag (Name) @node\
                  (#eq? @node "tested")\
                  (Attribute (Name) @string\
                             (AttValue) @subprogram)\
            )'
          local captures_flag = ""
          local query_subprograms =
            vim.treesitter.query.parse("xml", query_subpr_string)
          for _, subpr_node in query_subprograms:iter_captures(filename_node, 0) do
            text = vim.treesitter.get_node_text(subpr_node, 0)

            if captures_flag == "name" then
              subpr_test.name = text:gsub('"', "")
            elseif captures_flag == "line" then
              subpr_test.line = text:gsub('"', "")
            elseif captures_flag == "column" then
              subpr_test.column = text:gsub('"', "")
              table.insert(source_files[filename], subpr_test)
              subpr_test = {}
            end

            captures_flag = text:gsub('"', "")
          end
          table.insert(tests, source_files)
        end
      end
    end
  end
  print(vim.inspect(tests))

  -- Check the correct number of tests are detected, just for debugging
  -- local count = 0
  -- for _, test in pairs(tests) do
  --   for _, t in pairs(test) do
  --     count = count + #t
  --   end
  -- end
  -- print(vim.inspect(count))
end, {})
