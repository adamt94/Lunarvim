local M = {}

local SESSIONS_DIR  = vim.fn.expand("~/.claude/sessions/")
local SETTINGS_PATH = vim.fn.expand("~/.claude/settings.json")

local EFFORT_ICONS = { low = "▁", medium = "▄", high = "█", max = "▇" }

local MODEL_SHORT = {
  ["claude-opus-4-7"]           = "opus",
  ["claude-opus-4-6"]           = "opus",
  ["claude-sonnet-4-6"]         = "sonnet",
  ["claude-haiku-4-5-20251001"] = "haiku",
  ["claude-haiku-4-5"]          = "haiku",
}

-- ── Caching ───────────────────────────────────────────────────────────────────

local cache = { sessions = nil, last_scan = 0, settings = nil }

local function pid_alive(pid)
  if not pid then return false end
  local ok = pcall(vim.uv.kill, pid, 0)
  return ok
end

local function read_sessions()
  local now = os.time()
  if cache.sessions and now - cache.last_scan < 2 then return cache.sessions end
  local sessions = {}
  for _, f in ipairs(vim.fn.glob(SESSIONS_DIR .. "*.json", false, true)) do
    local lines = vim.fn.readfile(f)
    if #lines > 0 then
      local ok, data = pcall(vim.json.decode, lines[1])
      if ok and data.pid and pid_alive(data.pid) then
        sessions[#sessions + 1] = data
      end
    end
  end
  cache.sessions   = sessions
  cache.last_scan  = now
  return sessions
end

local function read_settings()
  if cache.settings then return cache.settings end
  if vim.fn.filereadable(SETTINGS_PATH) == 0 then return {} end
  local lines = vim.fn.readfile(SETTINGS_PATH)
  if #lines == 0 then return {} end
  local ok, data  = pcall(vim.json.decode, table.concat(lines, ""))
  cache.settings  = ok and data or {}
  return cache.settings
end

-- ── Components ────────────────────────────────────────────────────────────────

-- Active AI thread: "icon ⚙ name" (busy) / "icon ◆ name" (idle) / "" (none)
function M.thread()
  local info = require("lunarvim.ui.sidebar").get_active_info()
  if not info then return "" end

  local thread = require("lunarvim.threads").get(info.id)
  if not thread then return "" end

  local tools = require("lunarvim.threads").AI_TOOLS
  local tool  = tools[thread.ai_tool] or { icon = "?" }

  local alive = info.job_id and vim.fn.jobwait({ info.job_id }, 0)[1] == -1

  local status = "·"
  if alive then
    status = "◆"  -- default: alive but no session file match
    if thread.ai_tool == "claude" then
      for _, s in ipairs(read_sessions()) do
        if s.cwd == thread.project then
          status = s.status == "busy" and "⚙" or "◆"
          break
        end
      end
    end
  end

  return tool.icon .. " " .. status .. " " .. thread.name
end

-- Effort level from ~/.claude/settings.json: "▄ medium"
function M.effort()
  if not require("lunarvim.ui.sidebar").get_active_info() then return "" end
  local active_thread = require("lunarvim.threads").get(
    require("lunarvim.ui.sidebar").get_active_info().id)
  if not active_thread or active_thread.ai_tool ~= "claude" then return "" end

  local settings = read_settings()
  local level    = settings.effortLevel
  if not level then return "" end
  return (EFFORT_ICONS[level] or "?") .. " " .. level
end

-- Git branch of the active thread's project
function M.project_branch()
  local info = require("lunarvim.ui.sidebar").get_active_info()
  if not info then return "" end
  local thread = require("lunarvim.threads").get(info.id)
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
        { M.effort,         color = { fg = "#a6e3a1" } },
        { M.project_branch, color = { fg = "#cba6f7" } },
      },
      lualine_y = {
        { M.thread, color = { fg = "#89b4fa" } },
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
