return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    opts = function(_, opts)
      opts.transparent = true
      opts.italic_comments = true
      opts.borderless_telescope = false
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato",
    },
  },

  --{
  --  "lalitmee/cobalt2.nvim",
  --  event = { "ColorSchemePre" }, -- if you want to lazy load
  --  dependencies = { "tjdevries/colorbuddy.nvim", tag = "v1.0.0" },
  --  init = function()
  --    require("colorbuddy").colorscheme("cobalt2")
  --  end,
  --},

  -- modicator (auto color line number based on vim mode)
  --{
  --  "mawkler/modicator.nvim",
  --  dependencies = "scottmckendry/cyberdream.nvim",
  --  init = function()
  --    -- These are required for Modicator to work
  --    vim.o.cursorline = false
  --    vim.o.number = true
  --    vim.o.termguicolors = true
  --  end,
  --  opts = {},
  --},
}
