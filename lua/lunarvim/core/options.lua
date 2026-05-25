local M = {}

function M.apply()
  vim.g.mapleader      = " "
  vim.g.maplocalleader = "\\"

  local opt = vim.opt

  -- Appearance
  opt.number         = true
  opt.relativenumber = true
  opt.termguicolors  = true
  opt.cursorline     = true
  opt.signcolumn     = "yes"
  opt.colorcolumn    = "100"
  opt.scrolloff      = 8
  opt.sidescrolloff  = 8
  opt.wrap           = false
  opt.list           = true
  opt.listchars      = { tab = "» ", trail = "·", nbsp = "␣" }

  -- Indentation
  opt.expandtab   = true
  opt.shiftwidth  = 2
  opt.tabstop     = 2
  opt.smartindent = true
  opt.shiftround  = true

  -- Search
  opt.ignorecase = true
  opt.smartcase  = true
  opt.hlsearch   = true
  opt.incsearch  = true

  -- Splits open right and below (more natural)
  opt.splitright = true
  opt.splitbelow = true

  -- Editing
  opt.undofile   = true
  opt.clipboard  = "unnamedplus"
  opt.mouse      = "a"
  opt.updatetime = 250
  opt.timeoutlen = 300

  -- Fold (use treesitter when available, fall back to indent)
  opt.foldmethod = "indent"
  opt.foldlevel  = 99
end

return M
