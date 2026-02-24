vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("AdaLSPAttach", { clear = true }),
  pattern = {
    "*.ad[bs]",
  },
  callback = function()
    if require("gnattest.ada_ls").get_ada_ls then
      require("gnattest.ada_ls").setup()
      require("gnattest.read_only").setup()
    else
      require("gnattest.utils").notify(
        "Ada LSP client not found",
        vim.log.levels.WARN
      )
    end
  end,
})
