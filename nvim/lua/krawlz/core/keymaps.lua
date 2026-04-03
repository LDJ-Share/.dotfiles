vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab


-- Paste from system clipboard
keymap.set({ "n", "x" }, "<C-v>", '"+p', { noremap = true, silent = true })
keymap.set("i", "<C-v>", "<C-r>+", { noremap = true, silent = true })
keymap.set("c", "<C-v>", "<C-r>+", { noremap = true, silent = true })

-- Copy selection to system clipboard
keymap.set("x", "<C-c>", '"+y', { noremap = true, silent = true })

-- Undo / redo
keymap.set("n", "<C-z>", "u", { noremap = true, silent = true })
keymap.set("i", "<C-z>", "<C-o>u", { noremap = true, silent = true })

-- keymap.set("n", "<C-y>", "<C-r>", { noremap = true, silent = true })
-- keymap.set("i", "<C-y>", "<C-o><C-r>", { noremap = true, silent = true })

-- Try Windows-style redo
keymap.set("n", "<C-S-z>", "<C-r>", { noremap = true, silent = true })
keymap.set("i", "<C-S-z>", "<C-o><C-r>", { noremap = true, silent = true })

-- Select all
-- keymap.set("n", "<C-a>", "ggVG", { noremap = true, silent = true })
keymap.set("i", "<C-a>", "<Esc>ggVG", { noremap = true, silent = true })