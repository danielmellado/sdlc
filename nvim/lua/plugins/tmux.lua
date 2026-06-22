return {
  -- Seamless navigation between tmux panes and neovim splits
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    opts = {
      copy_sync = { enable = false },
      navigation = {
        enable_default_keybindings = true,
        cycle_navigation = true,
        persist_zoom = false,
      },
      resize = {
        enable_default_keybindings = true,
        resize_step_x = 2,
        resize_step_y = 2,
      },
    },
  },
}
