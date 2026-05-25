local M = {}

function M.apply()
  vim.g.mapleader = " "
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.termguicolors = true
end

return M
