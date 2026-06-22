local map = vim.keymap.set

map("n", "<CR>", "<cmd>noh<CR><CR>", { desc = "Clear search highlight" })

map("n", "<A-Up>", "<cmd>wincmd k<CR>", { desc = "Move to pane above" })
map("n", "<A-Down>", "<cmd>wincmd j<CR>", { desc = "Move to pane below" })
map("n", "<A-Left>", "<cmd>wincmd h<CR>", { desc = "Move to left pane" })
map("n", "<A-Right>", "<cmd>wincmd l<CR>", { desc = "Move to right pane" })

map("n", "<C-Right>", "<cmd>tabn<CR>", { desc = "Next tab" })
map("n", "<C-Left>", "<cmd>tabp<CR>", { desc = "Previous tab" })
map("n", "<C-t>", "<cmd>tabnew<CR>", { desc = "New tab" })

-- Better window resizing
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-S-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-S-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Move lines in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centered when scrolling
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")

-- Keep cursor centered when searching
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Better paste in visual mode (don't clobber register)
map("x", "<leader>p", [["_dP]], { desc = "Paste without clobbering register" })

-- Quick save
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })

-- Diagnostic navigation
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
