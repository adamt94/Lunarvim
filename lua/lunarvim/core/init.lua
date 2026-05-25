local M = {}

function M.setup()
  require("lunarvim.core.options").apply()
  require("lunarvim.plugins").load()
  require("lunarvim.keymaps").setup()
end

return M
