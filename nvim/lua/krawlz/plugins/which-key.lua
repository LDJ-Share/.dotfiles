return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 500,
    icons = {
      mappings = true,
    },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    -- Register group labels for key prefixes
    wk.add({
      { "<leader>n",  group = "nohlsearch" },
      { "<leader>s",  group = "splits" },
      { "<leader>t",  group = "tabs" },
      { "<leader>f",  group = "find (telescope)" },
      { "<leader>g",  group = "git" },
      { "<leader>d",  group = "debug" },
      { "<leader>r",  group = "lsp/refactor" },
      { "<leader>c",  group = "code actions" },
      { "<leader>x",  group = "trouble/diagnostics" },
      { "<leader>b",  group = "breakpoints" },
    })
  end,
}
