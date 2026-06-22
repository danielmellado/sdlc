local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.title = true
opt.ruler = true
opt.cursorline = true
opt.colorcolumn = "119"

opt.backup = false
opt.writebackup = false
opt.swapfile = false

opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

opt.splitbelow = true
opt.splitright = true

opt.completeopt = { "menuone", "noselect", "preview" }

opt.textwidth = 79
opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.softtabstop = 4
opt.shiftround = true
opt.autoindent = true
opt.smartindent = true

opt.foldmethod = "indent"
opt.foldlevel = 99

opt.termguicolors = true
opt.background = "dark"
opt.encoding = "utf-8"
opt.signcolumn = "yes"
opt.laststatus = 3
opt.showmode = false

opt.scrolloff = 8
opt.sidescrolloff = 8

opt.updatetime = 250
opt.timeoutlen = 300

opt.undofile = true

opt.mouse = "a"

opt.clipboard = "unnamedplus"
