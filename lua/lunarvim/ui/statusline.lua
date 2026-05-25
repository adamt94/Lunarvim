local M = {}

local status = require("lunarvim.ai.status")

local function active_thread()
  local info = require("lunarvim.ui.sidebar").get_active_info()
  if not info then return nil, nil end
  local thread = require("lunarvim.threads").get(info.id)
  return thread, info
end

-- Active AI thread: "provider status name".
function M.thread()
  local thread, info = active_thread()
  if not thread then return "" end

  local tools = require("lunarvim.threads").AI_TOOLS
  local tool = tools[thread.ai_tool] or { icon = "?" }
  local state = status.for_thread(thread, info.job_id)

  return tool.icon .. " " .. state.icon .. " " .. state.label .. " " .. thread.name
end

function M.thread_color()
  local thread, info = active_thread()
  if not thread then return { fg = status.colors.overlay } end
  return { fg = status.for_thread(thread, info.job_id).color }
end

-- Provider metadata when the CLI exposes it locally.
function M.session_context()
  local thread = active_thread()
  if not thread then return "" end
  return status.context_for_thread(thread)
end

-- Git branch of the active thread's project.
function M.project_branch()
  local thread = active_thread()
  if not thread or not thread.project then return "" end
  if thread.project:find("@") or thread.project:find("^ssh://") then return "" end
  local branch = vim.trim(vim.fn.system(
    "git -C " .. vim.fn.shellescape(thread.project) .. " branch --show-current 2>/dev/null"))
  return branch ~= "" and " " .. branch or ""
end

-- ── Lualine opts ──────────────────────────────────────────────────────────────

function M.lualine_opts()
  return {
    options = {
      theme                = "catppuccin",
      component_separators = "|",
      section_separators   = { left = "", right = "" },
      globalstatus         = true,
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = {
        { M.session_context, color = { fg = status.colors.green } },
        { M.project_branch,  color = { fg = status.colors.mauve } },
      },
      lualine_y = {
        { M.thread, color = M.thread_color },
      },
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_c = { { "filename", path = 1 } },
      lualine_x = { "location" },
    },
  }
end

return M
