local M = {}

-- Tracks editor context that can be fed to an AI terminal session.
-- No provider coupling — AI runs in a toggleterm panel; this module
-- handles what gets sent to it and what gets pulled back.
M.context = {
  buffers = {},    -- open buffers relevant to current task
  selection = nil, -- last visual selection
  thread_id = nil, -- future: named conversation thread
}

function M.setup()
  -- Capture visual selections so they're available to AI panel commands
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = "v:n",
    callback = function()
      local start = vim.fn.getpos("'<")
      local finish = vim.fn.getpos("'>")
      local lines = vim.fn.getregion(start, finish, { type = "v" })
      if #lines > 0 then
        M.context.selection = table.concat(lines, "\n")
      end
    end,
  })
end

return M
