return {
  -- Claude Code integration via WebSocket MCP
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<CR>", desc = "Open Claude Code" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<CR>", desc = "Add current buffer to Claude" },
      { "<leader>as", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Send selection to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<CR>",
        desc = "Add file from tree to Claude",
        ft = { "neo-tree" },
      },
    },
    opts = {
      auto_start = true,
      terminal = {
        split_side = "right",
        split_width_percentage = 0.4,
      },
    },
  },

  -- Snacks.nvim for enhanced terminal support
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      terminal = { enabled = true },
      notifier = { enabled = true },
      statuscolumn = { enabled = false },
    },
  },
}
