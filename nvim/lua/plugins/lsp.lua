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
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "gopls",
        "pyright",
        "rust_analyzer",
        "lua_ls",
        "yamlls",
        "bashls",
      },
      automatic_enable = true,
    },
  },

  -- nvim-lspconfig provides server definitions for vim.lsp.config
  {
    "neovim/nvim-lspconfig",
    lazy = true,
  },

  -- cmp-nvim-lsp capabilities + keymaps + per-server config
  {
    "hrsh7th/cmp-nvim-lsp",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Apply completion capabilities to all servers
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- Per-server configuration
      vim.lsp.config("gopls", {
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

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
          },
        },
      })

      vim.lsp.config("lua_ls", {
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

      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemas = {
              kubernetes = "/*.k8s.yaml",
              ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
            },
          },
        },
      })

      -- LSP keymaps (applied when any server attaches)
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("sdlc-lsp-keymaps", { clear = true }),
        callback = function(ev)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
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
        end,
      })
    end,
  },
}
