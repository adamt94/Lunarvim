local M = {}

function M.setup()
  require("lunarvim.core.options").apply()
  require("lunarvim.plugins").load()
end

return M
