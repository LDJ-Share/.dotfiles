require("krawlz.core.options")

if vim.g.vscode then
    require("krawlz.core.keymaps-vscode")
else
    require("krawlz.core.keymaps")
end