local M = {}

--- Set a keymap with silent = true by default.
--- @param mode string|table vim mode(s)
--- @param lhs string left-hand side
--- @param rhs string|function right-hand side
--- @param opts? table extra opts passed to vim.keymap.set
function M.map(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { silent = true }, opts or {}))
end

return M
