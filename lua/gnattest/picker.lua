local M = {}

function M.select_tests()
  local xml = require("gnattest.xml")
  local tests_info = xml.get_xml_info()
  if tests_info == nil or next(tests_info) == nil then
    return
  end

  local utils = require("gnattest.utils")
  if not utils.try_require("telescope") then
    utils.notify(
      "Telescope is required for :Gnattest run_select",
      vim.log.levels.ERROR
    )
    return
  end

  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local runner = require("gnattest.runner")
  local test_dir = require("gnattest.ada_ls").get_tests_dir()

  local entries = {}

  for source_file, files in pairs(tests_info) do
    for pkg, pkg_info in pairs(files) do
      for _, info in pairs(pkg_info) do
        table.insert(entries, {
          display = pkg .. ":" .. info.source.name,
          ordinal = pkg .. ":" .. info.source.name,
          filename = source_file,
          path = (test_dir or ".") .. "/" .. info.tests[1].file,
          lnum = tonumber(info.tests[1].line) + 5, -- Adjust line number to point to the test body
          source_line = info.source.line,
        })
      end
    end
  end

  pickers
    .new({}, {
      prompt_title = "Select Tests to Run",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.ordinal,
            path = entry.path,
            lnum = entry.lnum,
            filename = entry.filename,
            source_line = entry.source_line,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection()
          local current = action_state.get_selected_entry()

          actions.close(prompt_bufnr)

          if #selections == 0 and current then
            selections = { current }
          elseif #selections == 0 then
            utils.notify("No tests selected", vim.log.levels.WARN)
            return
          end

          if runner.prepare_run() then
            for _, selection in ipairs(selections) do
              runner.run_test(
                selection.value.filename,
                selection.value.source_line
              )
            end
          end
        end)
        return true
      end,
    })
    :find()
end

return M
