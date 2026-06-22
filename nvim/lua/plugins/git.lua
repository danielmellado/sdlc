return {
  -- Fugitive
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gvdiffsplit", "Gread", "Gwrite", "GBrowse" },
    keys = {
      { "<leader>gg", "<cmd>Git<CR>", desc = "Git status (fugitive)" },
      { "<leader>gb", "<cmd>Git blame<CR>", desc = "Git blame" },
      { "<leader>gd", "<cmd>Gvdiffsplit<CR>", desc = "Git diff split" },
    },
  },

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
        end

        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Previous hunk")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
        map("n", "<leader>gl", gs.blame_line, "Blame line")
      end,
    },
  },

  -- Diffview for advanced diff/merge visualization
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gD", "<cmd>DiffviewOpen<CR>", desc = "Diffview open" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
    },
    opts = {},
  },
}
