local M = {}

local specs = {
  -- Home dashboard
  {
    "goolord/alpha-nvim",
    event        = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config       = function() require("lunarvim.ui.dashboard").setup() end,
  },

  -- Colorschemes — active theme configured in lua/lunarvim/ui/theme.lua
  { "catppuccin/nvim",              name = "catppuccin",  priority = 1000, lazy = false },
  { "folke/tokyonight.nvim",        name = "tokyonight",  priority = 1000, lazy = false },

  -- Syntax / parsing
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = { "lua", "python", "javascript", "typescript", "bash", "json", "markdown" },
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- Fuzzy finder
  { "nvim-lua/plenary.nvim", lazy = true },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      defaults = {
        prompt_prefix = "  ",
        selection_caret = " ",
      },
    },
  },

  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      filesystem = {
        filtered_items = { hide_dotfiles = false },
        follow_current_file = { enabled = true },
      },
      window = { width = 30 },
    },
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event        = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts         = function() return require("lunarvim.ui.statusline").lualine_opts() end,
  },

  -- Keymap hints (loaded early so group labels appear immediately)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 300,
    },
  },

  -- Better vim.ui.select / vim.ui.input (arrow-key selector, Telescope backend)
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      select = {
        backend = { "telescope", "builtin" },
        telescope = require("telescope.themes").get_cursor({ initial_mode = "normal" }),
      },
      input = {
        default_prompt = "  ",
        win_options    = { winblend = 0 },
      },
    },
  },

  -- Comment toggling: gcc (line), gc (motion/visual)
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },

  -- Terminal panels (foundation for AI workflow); keys live in keymaps/init.lua
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = "ToggleTerm",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then return 15
        elseif term.direction == "vertical" then return math.floor(vim.o.columns * 0.4)
        end
      end,
      float_opts = { border = "curved" },
      shade_terminals = false,
    },
  },
}

function M.load()
  local theme = require("lunarvim.ui.theme")
  require("lazy").setup(specs, {
    defaults = { lazy = true },
    install  = { colorscheme = { theme.colorscheme } },
    performance = {
      rtp = {
        disabled_plugins = {
          "gzip", "matchit", "matchparen", "netrwPlugin",
          "tarPlugin", "tohtml", "tutor", "zipPlugin",
        },
      },
    },
  })

  theme.apply()
end

return M
