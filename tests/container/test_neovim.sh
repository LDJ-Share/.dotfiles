#!/usr/bin/env bash
# test_neovim.sh — verify lazy.nvim plugins and Mason LSPs/tools are pre-installed
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

LAZY_DIR="${HOME}/.local/share/nvim/lazy"
MASON_BIN="${HOME}/.local/share/nvim/mason/bin"
MASON_PKG="${HOME}/.local/share/nvim/mason/packages"

echo "=== Neovim: lazy.nvim plugins installed ==="
check_dir "${LAZY_DIR}"

# All 51 plugins from lazy-lock.json must be present as directories
EXPECTED_PLUGINS=(
  LuaSnip
  alpha-nvim
  auto-session
  bufferline.nvim
  cmp-buffer
  cmp-nvim-lsp
  cmp-path
  cmp_luasnip
  conform.nvim
  dressing.nvim
  friendly-snippets
  gitsigns.nvim
  indent-blankline.nvim
  lazy.nvim
  lazydev.nvim
  lazygit.nvim
  lspkind.nvim
  lualine.nvim
  mason-lspconfig.nvim
  mason-nvim-dap.nvim
  mason-tool-installer.nvim
  mason.nvim
  noice.nvim
  nui.nvim
  nvim-autopairs
  nvim-cmp
  nvim-dap
  nvim-dap-ui
  nvim-dap-virtual-text
  nvim-lint
  nvim-lsp-file-operations
  nvim-lspconfig
  nvim-nio
  nvim-notify
  nvim-surround
  nvim-tree.lua
  nvim-treesitter
  nvim-treesitter-textobjects
  nvim-ts-autotag
  nvim-web-devicons
  plenary.nvim
  substitute.nvim
  telescope-fzf-native.nvim
  telescope.nvim
  todo-comments.nvim
  tokyonight.nvim
  trouble.nvim
  vim-maximizer
  vim-tmux-navigator
  which-key.nvim
)

for plugin in "${EXPECTED_PLUGINS[@]}"; do
  check_dir "${LAZY_DIR}/${plugin}"
done

echo ""
echo "=== Neovim: Mason LSP servers installed ==="
check_dir "${MASON_BIN}"

# mason-lspconfig ensure_installed list (mason package names → binary names)
declare -A LSP_BINS=(
  [ts_ls]="typescript-language-server"
  [html]="vscode-html-language-server"
  [cssls]="vscode-css-language-server"
  [tailwindcss]="tailwindcss-language-server"
  [svelte]="sveltekit-languageserver"
  [lua_ls]="lua-language-server"
  [graphql]="graphql-lsp"
  [emmet_ls]="emmet-ls"
  [prismals]="prisma-language-server"
  [pyright]="pyright"
  [eslint]="vscode-eslint-language-server"
  [gopls]="gopls"
  [bashls]="bash-language-server"
  [jsonls]="vscode-json-language-server"
  [omnisharp]="OmniSharp"
  [powershell_es]="pwsh"
)

for server in "${!LSP_BINS[@]}"; do
  bin="${LSP_BINS[$server]}"
  check "mason LSP: ${server} (${bin})" test -f "${MASON_BIN}/${bin}"
done

echo ""
echo "=== Neovim: Mason tools installed ==="
# mason-tool-installer ensure_installed list
MASON_TOOLS=(
  prettier
  stylua
  eslint_d
  shfmt
  shellcheck
  goimports
  csharpier
  netcoredbg
)

for tool in "${MASON_TOOLS[@]}"; do
  # Tools may install as the exact name or as a package directory
  check "mason tool: ${tool}" bash -c \
    "test -f '${MASON_BIN}/${tool}' || test -d '${MASON_PKG}/${tool}'"
done

echo ""
echo "=== Neovim: config is stowed ==="
check_file "${HOME}/.config/nvim/init.lua"
check_file "${HOME}/.config/nvim/lua/krawlz/lazy.lua"
check_file "${HOME}/.config/nvim/lua/krawlz/plugins/lsp/mason.lua"

echo ""
echo "=== Neovim: headless startup (no errors) ==="
check "nvim --headless exits cleanly" \
  nvim --headless -c "lua print('ok')" -c "qa" 2>/dev/null

summary
