return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  opts = {
    lsp = {
      -- override markdown rendering so that cmp and other plugins use Treesitter
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,        -- keep / search at the bottom
      command_palette = true,      -- position the cmdline and popupmenu together as a popup
      long_message_to_split = true, -- long messages go to a split
      inc_rename = false,
      lsp_doc_border = true,       -- add a border to hover docs and signature help
    },
  },
}
