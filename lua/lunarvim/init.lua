local M = {}

-- Plugin entry point. Safe to call from AstroNvim or any other config.
-- Standalone config calls lunarvim.core.setup() separately (see root init.lua).
function M.setup(opts)
  local cfg = require("lunarvim.config").set(opts)
  require("lunarvim.ai").setup()
  require("lunarvim.keymaps.ai").setup(cfg)
end

return M
