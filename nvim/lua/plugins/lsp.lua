return {
  -- Mason: LSP/DAP/linter/formatter installer
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {},
  },

  -- Bridge between mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "gopls",
        "pyright",
        "rust_analyzer",
        "lua_ls",
        "yamlls",
        "bashls",
      },
    },
  },

  -- LSP config
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(_, bufnr)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
        end

        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("gr", vim.lsp.buf.references, "References")
        map("gi", vim.lsp.buf.implementation, "Go to implementation")
        map("K", vim.lsp.buf.hover, "Hover documentation")
        map("<leader>la", vim.lsp.buf.code_action, "Code action")
        map("<leader>lr", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ls", vim.lsp.buf.signature_help, "Signature help")
        map("<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
        map("<leader>lt", vim.lsp.buf.type_definition, "Type definition")
      end

      -- Go
      lspconfig.gopls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              shadow = true,
            },
            staticcheck = true,
            gofumpt = true,
            usePlaceholders = true,
          },
        },
      })

      -- Python
      lspconfig.pyright.setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      -- Rust
      lspconfig.rust_analyzer.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
          },
        },
      })

      -- Lua (for neovim config editing)
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME },
            },
            diagnostics = { globals = { "vim" } },
            telemetry = { enable = false },
          },
        },
      })

      -- YAML
      lspconfig.yamlls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        settings = {
          yaml = {
            schemas = {
              kubernetes = "/*.k8s.yaml",
              ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
            },
          },
        },
      })

      -- Bash
      lspconfig.bashls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end,
  },
}
