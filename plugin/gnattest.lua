local test_project = "obj/gnattest/harness/test_driver.gpr"

vim.api.nvim_create_user_command("GNATtestBuild", function()
  vim.fn.system("gprbuild -P " .. test_project)
end, {})

vim.api.nvim_create_user_command("GNATtestClean", function()
  vim.fn.system("gprclean -P " .. test_project)
end, {})
