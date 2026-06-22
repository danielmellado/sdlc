local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Remove trailing whitespace on save
autocmd("BufWritePre", {
  group = augroup("TrimWhitespace", { clear = true }),
  pattern = "*",
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- Highlight trailing whitespace
autocmd({ "BufWinEnter", "InsertLeave" }, {
  group = augroup("HighlightWhitespace", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.bo.buftype == "" then
      vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
    end
  end,
})
vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "#ff0000" })

-- Git commit messages
autocmd("FileType", {
  group = augroup("GitCommit", { clear = true }),
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.textwidth = 72
    vim.opt_local.colorcolumn = "+1,51"
  end,
})

-- Markdown text width
autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("Markdown", { clear = true }),
  pattern = "*.md",
  callback = function()
    vim.opt_local.textwidth = 80
  end,
})

-- YAML 2-space indent
autocmd("FileType", {
  group = augroup("YamlIndent", { clear = true }),
  pattern = "yaml",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

-- RST colorcolumn
autocmd({ "BufNewFile", "BufRead" }, {
  group = augroup("RstColumn", { clear = true }),
  pattern = "*.rst",
  callback = function()
    vim.opt_local.colorcolumn = "79"
  end,
})

-- Reload files changed outside neovim
autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave" }, {
  group = augroup("AutoReload", { clear = true }),
  pattern = "*",
  command = "checktime",
})

-- Briefly highlight yanked text
autocmd("TextYankPost", {
  group = augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

-- Auto-resize splits when terminal is resized
autocmd("VimResized", {
  group = augroup("AutoResize", { clear = true }),
  command = "tabdo wincmd =",
})
