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

local tests = {}

vim.api.nvim_create_user_command("TSTest", function()
  local root = vim.treesitter.get_parser():parse()[1]:root()
  print(root)
  -- (STag (Name) @tag (#eq? @tag "unit")\
  --   (Attribute (AttValue) @string.special.path)\
  -- )'
  --
  local query_string = '\
  (content (element (STag ((Attribute ((Name) @tag.attribute)\
            (#eq? @tag.attribute "source_file")\
            (AttValue) @source_file))))\
  ) @element'

  local query_source_files = vim.treesitter.query.parse("xml", query_string)

  for i, node, metadata, match, tree in
    query_source_files:iter_captures(root, 0)
  do
    -- if query_source_files.captures[i] == "element" then
    local text = vim.treesitter.get_node_text(node, 0)
    local filename = text:gsub('"', "")
    print(node)
    print(query_source_files.captures[i])
    -- local source_files = {
    --   [filename] = {},
    -- }
    --
    -- query_string = '\
    --   (STag (Name) @node\
    --         (#eq? @node "tested")\
    --         (Attribute (AttValue) @subprogram)\
    --   )'
    --
    -- local query_subprograms = vim.treesitter.query.parse("xml", query_string)
    local filename_node = node
    print(filename_node)
    -- print(vim.inspect(filename_node))
    --
    -- local captures_count = 0
    -- local subpr_test = {}
    -- local subprogram = {}
    -- for _, n in query_subprograms:iter_captures(filename_node, 0) do
    --   --   -- if i % 2 == 0 then
    --   text = vim.treesitter.get_node_text(n, 0)
    --   if text == "tested" then
    --     captures_count = captures_count + 1
    --   else
    --     captures_count = captures_count - 1
    --     text = text:gsub('"', "")
    --     -- print(text)
    --     -- table.insert(subprogram, text)
    --     -- if captures_count == 0 then
    --     --   table.insert(subpr_test, subprogram)
    --     --   subprogram = {}
    --     -- end
    --   end
    --   --   table.insert(source_files[filename], subpr_test)
    -- end
    -- table.insert(tests, source_files)
    -- end
  end

  query_string = '\
        (STag (Name) @node\
              (#eq? @node "tested")\
              (Attribute (AttValue) @subprogram)\
        )'

  local query_subprograms = vim.treesitter.query.parse("xml", query_string)
  -- local filename_node =
  --   vim.treesitter.get_string_parser(filename, "xml")[1]:root()
  -- print(vim.inspect(filename_node))

  local captures_count = 0
  local subpr_test = {}
  local subprogram = {}
  for _, n in query_subprograms:iter_captures(root, 0) do
    --   -- if i % 2 == 0 then
    local text = vim.treesitter.get_node_text(n, 0)
    if text == "tested" then
      captures_count = captures_count + 1
    else
      captures_count = captures_count - 1
      text = text:gsub('"', "")
      print(text)
      -- table.insert(subprogram, text)
      -- if captures_count == 0 then
      --   table.insert(subpr_test, subprogram)
      --   subprogram = {}
      -- end
    end
    --   table.insert(source_files[filename], subpr_test)
  end
  -- table.insert(tests, source_files)

  -- query_string = '\
  --   (content (element (STag (Name) @tag\
  --         (#eq? @tag "tested")\
  --         (Attribute (AttValue) @subprogram)))\
  --   )'
  -- local query_subprograms = vim.treesitter.query.parse("xml", query_string)
  --
  -- for i, node in query_subprograms:iter_captures(root, 0) do
  --   -- if i % 2 == 0 then
  --   local subprograms = vim.treesitter.get_node_text(node, 0)
  --   -- subprograms = subprograms:gsub('"', "")
  --   table.insert(source_files, subprograms)
  --   print(subprograms)
  --   -- end
  -- end
  -- print(vim.inspect(tests))
end, {})
