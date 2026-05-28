local M = {}

function M.setup(cfg)
  local map    = require("lunarvim.utils").map
  local prefix = cfg.keymap_prefix
  local k      = cfg.keys

  -- Register which-key group label if which-key is present
  vim.api.nvim_create_autocmd("User", {
    pattern  = "VeryLazy",
    once     = true,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if not ok then return end
      wk.add({ { prefix, group = cfg.which_key_label } })
    end,
  })

  map("n", prefix .. k.toggle, function()
    require("lunarvim.ui.sidebar").toggle()
  end, { desc = "Toggle thread sidebar" })

  map("n", prefix .. k.new, function()
    require("lunarvim.ui.sidebar").action_new()
  end, { desc = "New thread" })

  map("n", prefix .. k.resume, function()
    require("lunarvim.threads").pick()
  end, { desc = "Resume thread" })

  map("n", prefix .. k.project, function()
    if not require("lunarvim.ui.sidebar").is_open() then
      require("lunarvim.ui.sidebar").open()
    end
    vim.schedule(function() require("lunarvim.ui.sidebar").action_add_project() end)
  end, { desc = "Add project" })

  map("n", prefix .. k.explorer, function()
    require("lunarvim.ui.sidebar").swap_sidebar()
  end, { desc = "Swap sidebar (threads ↔ files)" })

  -- Terminal insert mode: escape and jump to sidebar
  local focus_key = cfg.terminal_focus_key
  if focus_key and focus_key ~= "" then
    map("t", focus_key, function()
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
      vim.schedule(function() require("lunarvim.ui.sidebar").open() end)
    end, { desc = "Exit terminal and focus sidebar" })
  end
end

return M
