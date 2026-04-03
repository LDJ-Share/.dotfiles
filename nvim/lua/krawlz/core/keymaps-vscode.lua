vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

-- VSCode extension
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local vscode = require("vscode")

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Files / navigation
map("n", "<leader>ff", function()
    vscode.action("workbench.action.quickOpen")
end, opts)

map("n", "<leader>fg", function()
    vscode.action("workbench.action.findInFiles")
end, opts)

map("n", "<leader>fr", function()
    vscode.action("workbench.action.openRecent")
end, opts)

map("n", "<leader>e", function()
    vscode.action("workbench.view.explorer")
end, opts)

map("n", "<leader>b", function()
    vscode.action("workbench.action.showAllEditors")
end, opts)

-- Save / editor lifecycle
map("n", "<leader>w", function()
    vscode.action("workbench.action.files.save")
end, opts)

map("n", "<leader>W", function()
    vscode.action("workbench.action.files.saveAll")
end, opts)

map("n", "<leader>q", function()
    vscode.action("workbench.action.closeActiveEditor")
end, opts)

map("n", "<leader>Q", function()
    vscode.action("workbench.action.closeAllEditors")
end, opts)

-- Symbols / code navigation
map("n", "<leader>ss", function()
    vscode.action("workbench.action.gotoSymbol")
end, opts)

map("n", "<leader>sS", function()
    vscode.action("workbench.action.showAllSymbols")
end, opts)

map("n", "gd", function()
    vscode.action("editor.action.revealDefinition")
end, opts)

map("n", "gD", function()
    vscode.action("editor.action.revealDeclaration")
end, opts)

map("n", "gr", function()
    vscode.action("editor.action.goToReferences")
end, opts)

map("n", "gi", function()
    vscode.action("editor.action.goToImplementation")
end, opts)

map("n", "gy", function()
    vscode.action("editor.action.goToTypeDefinition")
end, opts)

-- Diagnostics / problems
map("n", "]d", function()
    vscode.action("editor.action.marker.next")
end, opts)

map("n", "[d", function()
    vscode.action("editor.action.marker.prev")
end, opts)

map("n", "<leader>xx", function()
    vscode.action("workbench.actions.view.problems")
end, opts)

-- Refactor / code actions
map({ "n", "x" }, "<leader>ca", function()
    vscode.action("editor.action.codeAction")
end, opts)

map("n", "<leader>rn", function()
    vscode.action("editor.action.rename")
end, opts)

map("n", "<leader>f", function()
    vscode.call("editor.action.formatDocument")
end, opts)

map("x", "<leader>f", function()
    vscode.call("editor.action.formatSelection")
end, opts)

-- Search under cursor
map("n", "<leader>*", function()
    vscode.action("workbench.action.findInFiles", {
  args = { query = vim.fn.expand("<cword>") },
})
end, opts)

-- Git
map("n", "<leader>gs", function()
    vscode.action("workbench.view.scm")
end, opts)

map("n", "<leader>gp", function()
    vscode.action("workbench.action.showCommands", {
  args = { "Git: Pull" },
})
end, opts)

map("n", "<leader>gP", function()
    vscode.action("workbench.action.showCommands", {
  args = { "Git: Push" },
})
end, opts)

-- Terminal
map("n", "<leader>tt", function()
    vscode.action("workbench.action.terminal.toggleTerminal")
end, opts)

map("n", "<leader>tn", function()
    vscode.action("workbench.action.terminal.new")
end, opts)

-- Useful VS Code surface
map("n", "<leader>p", function()
    vscode.action("workbench.action.showCommands")
end, opts)

map("n", "<leader>u", function()
    vscode.action("workbench.action.openSettingsJson")
end, opts)