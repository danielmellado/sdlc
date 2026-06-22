-- Leader key must be set before lazy.nvim loads
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("options")
require("keymaps")
require("autocmds")
require("plugins")
