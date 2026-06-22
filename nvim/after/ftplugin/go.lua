vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = false
vim.opt_local.colorcolumn = "119"

-- Trigger omnifunc on dot
vim.keymap.set("i", ".", ".<C-x><C-o>", { buffer = true })
