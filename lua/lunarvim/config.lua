local M = {}

local defaults = {
  keymap_prefix      = "<leader>a",
  sidebar_width      = 40,
  terminal_focus_key = "<C-f>",
  which_key_label    = "AI Threads",
  keys = {
    toggle   = "s",
    new      = "n",
    resume   = "r",
    project  = "p",
    explorer = "e",
  },
}

local _cfg

-- Merge user opts with defaults, store, and return resolved config.
function M.set(opts)
  _cfg = vim.tbl_deep_extend("force", defaults, opts or {})
  return _cfg
end

function M.get()
  return _cfg or defaults
end

return M
