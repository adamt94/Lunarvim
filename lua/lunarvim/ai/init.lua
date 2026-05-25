local M = {}

M.config = {
  provider = "openai",
  enabled = true,
  suggestion_mode = "inline",
}

function M.setup()
  -- Placeholder for AI provider wiring and prompt/session management.
  return M.config
end

return M
