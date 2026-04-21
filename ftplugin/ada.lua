vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("AdaLSPAttach", { clear = true }),
  pattern = {
    "*.ad[bs]",
  },
  callback = function()
    require("gnattest.ada_ls").setup()
    require("gnattest.read_only").setup()
  end,
})
