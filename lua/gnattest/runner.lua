local M = {
  qf_items = {},
  pending_runs = 0,
}

local function type_test_result(res)
  if res:find("PASSED") then
    return "I"
  else
    return "E"
  end
end

local function prepare_qf_item(pkg, test_info, line, type)
  local utils = require("gnattest.utils")
  local test_dir = require("gnattest.ada_ls").get_tests_dir()
  local lnum = tonumber(test_info.test.line)
  local col = tonumber(test_info.test.column)
  local file = utils.find_file(test_info.test.file, test_dir)

  if not file then
    file = test_info.test.file
    utils.notify(
      file .. " not found in " .. test_dir .. " directory",
      vim.log.levels.WARN
    )
  end

  -- Replace "corresponding" in the line with the actual package and test name
  line = line:gsub("corresponding", pkg .. ":" .. test_info.source.name)

  return {
    bufnr = 0,
    filename = file,
    lnum = lnum,
    col = col,
    text = line,
    type = type or "E",
  }
end

local function open_qf_list()
  table.sort(M.qf_items, function(a, b)
    if a.type ~= b.type then
      return a.type == "E" -- Errors come before info
    else
      return a.text < b.text
    end
  end)

  vim.fn.setqflist({}, "a", { title = "Gnattest run", items = M.qf_items })
  vim.cmd("copen")
end

local function on_exit_tests(obj)
  if obj.stderr and obj.stderr ~= "" then
    M.pending_runs = M.pending_runs - 1
    require("gnattest.utils").notify(
      "Error running tests: " .. obj.stderr,
      vim.log.levels.ERROR
    )
    return
  end

  local stdout = obj.stdout or ""
  if stdout == "" then
    M.pending_runs = M.pending_runs - 1
    require("gnattest.utils").notify("No tests were run", vim.log.levels.WARN)
    return
  end

  vim.schedule(function()
    local lines = vim.split(stdout, "\n")

    for _, line in ipairs(lines) do
      local _, pkg, test_info =
        require("gnattest.xml").get_test_from_src_file_line(
          vim.split(line, ":")[1], -- filename
          tonumber(vim.split(line, ":")[2]) -- line number
        )
      if test_info ~= nil and pkg ~= nil then
        table.insert(
          M.qf_items,
          prepare_qf_item(
            pkg,
            test_info,
            tostring(line),
            type_test_result(line)
          )
        )
      end
    end
    M.pending_runs = M.pending_runs - 1
    if M.pending_runs == 0 then
      open_qf_list()
    end
  end)
end

function M.build_tests()
  local obj = vim
    .system(
      { "gprbuild", "-P" .. require("gnattest.utils").get_gnattest_project() },
      { text = true }
    )
    :wait()

  if obj.stderr and obj.stderr ~= "" then
    print("Error building tests: " .. obj.stderr)
    return false
  else
    print("Tests built successfully")
    return true
  end
end

function M.prepare_run()
  if M.pending_runs == 0 and M.build_tests() then
    M.qf_items = {} -- Clear previous quickfix items
    vim.fn.setqflist({}, "r") -- Clear the quickfix list before adding new items
    return true
  end
  return false
end

function M.run_test(filename, lnum)
  local arg = ""
  if filename ~= nil and lnum ~= nil then
    arg = "--routines=" .. filename .. ":" .. lnum
  end

  M.pending_runs = M.pending_runs + 1

  vim.system({
    require("gnattest.ada_ls").get_harness_dir() .. "/test_runner",
    arg,
  }, { text = true }, on_exit_tests)
end

-- Test-specific exports - only exposed in test mode
if os.getenv("GNATTEST_TEST_MODE") then
  M.type_test_result = type_test_result
  M.prepare_qf_item = prepare_qf_item
  M.open_qf_list = open_qf_list
  M.on_exit_tests = on_exit_tests
end

return M
