return {
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      {
        "williamboman/mason.nvim",
        opts = {
          ui = {
            icons = {
              package_installed = "✓",
              package_pending = "➜",
              package_uninstalled = "✗",
            },
          },
        },
      },
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "ts_ls",
          "html",
          "cssls",
          "tailwindcss",
          "svelte",
          "lua_ls",
          "graphql",
          "emmet_ls",
          "prismals",
          "pyright",
          "eslint",
          "gopls",
          "bashls",
          "jsonls",
          "omnisharp",
        },
        handlers = {
          -- Default handler: start every installed server with cmp capabilities
          function(server_name)
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            require("lspconfig")[server_name].setup({
              capabilities = capabilities,
            })
          end,
          -- lua_ls needs Neovim globals so diagnostics don't flag `vim`
          lua_ls = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            require("lspconfig").lua_ls.setup({
              capabilities = capabilities,
              settings = {
                Lua = {
                  diagnostics = { globals = { "vim" } },
                  completion = { callSnippet = "Replace" },
                },
              },
            })
          end,
          -- omnisharp: enable Roslyn analyzers and import completion
          omnisharp = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            require("lspconfig").omnisharp.setup({
              capabilities = capabilities,
              settings = {
                FormattingOptions = {
                  EnableEditorConfigSupport = true,
                  OrganizeImports = true,
                },
                RoslynExtensionsOptions = {
                  EnableAnalyzersSupport = true,
                  EnableImportCompletion = true,
                  AnalyzeOpenDocumentsOnly = false,
                },
                Sdk = { IncludePrereleases = false },
              },
            })
          end,
          -- gopls: enable all analyses and staticcheck
          gopls = function()
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            require("lspconfig").gopls.setup({
              capabilities = capabilities,
              settings = {
                gopls = {
                  analyses = { unusedparams = true },
                  staticcheck = true,
                  gofumpt = true,
                },
              },
            })
          end,
        },
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      run_on_start = true,
      ensure_installed = {
        "prettier",    -- JS/TS/CSS/HTML/JSON/YAML formatter
        "stylua",      -- Lua formatter
        "isort",       -- Python import sorter
        "black",       -- Python formatter
        "pylint",      -- Python linter
        "eslint_d",    -- JS/TS linter (fast daemon)
        "shfmt",       -- Shell formatter
        "shellcheck",  -- Shell linter
        "goimports",   -- Go import organiser + formatter
        "csharpier",   -- C# opinionated formatter
        "netcoredbg",  -- C# / .NET debugger
      },
    },
    dependencies = {
      "williamboman/mason.nvim",
    },
  },
}
