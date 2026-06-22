return {
  -- Formatting
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>lf",
        function() require("conform").format({ async = true, lsp_fallback = true }) end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        go = { "gofumpt", "goimports" },
        python = { "ruff_format", "ruff_fix" },
        rust = { "rustfmt" },
        lua = { "stylua" },
        yaml = { "yamlfmt" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        json = { "jq" },
        markdown = { "mdformat" },
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_fallback = true,
      },
    },
  },

  -- Linting
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      local all_linters = {
        go = { "golangcilint" },
        python = { "ruff" },
        yaml = { "yamllint" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        dockerfile = { "hadolint" },
        markdown = { "markdownlint" },
      }

      -- Only register linters that are actually installed
      for ft, linters in pairs(all_linters) do
        local available = vim.tbl_filter(function(l)
          local cmd = lint.linters[l] and lint.linters[l].cmd or l
          return vim.fn.executable(cmd) == 1
        end, linters)
        if #available > 0 then
          lint.linters_by_ft[ft] = available
        end
      end

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("NvimLint", { clear = true }),
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
