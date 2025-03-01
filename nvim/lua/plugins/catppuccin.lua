return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 0, -- Ensures it loads before other plugins
  config = function()
    require("catppuccin").setup({
      flavour = "mocha", -- Options: "latte", "frappe", "macchiato", "mocha"
      transparent_background = false, -- Set to true if you want transparency
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
        },
        telescope = true,
        gitsigns = true,
        nvimtree = true,
        dashboard = true,
        notify = true,
        mini = true,
      },
    })

    -- Set colorscheme
    vim.cmd("colorscheme catppuccin")
  end,
}
