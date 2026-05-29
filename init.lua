-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Standalone: load options, plugins, and all editor keymaps first.
require("lunarvim.core").setup()

-- Plugin API: AI threads, configurable keymaps.
-- AstroNvim users call only this line from their plugin spec.
require("lunarvim").setup({
  lazygit = {
    keymap = "<leader>gg",
  },
})
