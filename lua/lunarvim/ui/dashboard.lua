local M = {}

local function time_ago(timestamp)
  local diff = os.difftime(os.time(), timestamp)
  if diff < 3600  then return math.floor(diff / 60) .. "m ago" end
  if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
  return math.floor(diff / 86400) .. "d ago"
end

local function make_footer()
  local threads = require("lunarvim.threads")
  local recent  = threads.recent(3)
  if #recent == 0 then
    return { "", "  No threads yet — launch one above", "" }
  end
  local lines = { "", "  Recent", "" }
  for _, t in ipairs(recent) do
    local tool = threads.AI_TOOLS[t.ai_tool] or { label = t.ai_tool }
    lines[#lines + 1] = string.format(
      "  %-38s %-14s  %s",
      t.name, tool.label, time_ago(t.last_accessed)
    )
  end
  return lines
end

function M.setup()
  local ok, alpha = pcall(require, "alpha")
  if not ok then return end

  local dashboard = require("alpha.themes.dashboard")
  local threads   = require("lunarvim.threads")

  dashboard.section.header.val = {
    "",
    "  ╦  ╦ ╦╔╗╔╔═╗╦═╗╦  ╦╦╔╦╗  ",
    "  ║  ║ ║║║║╠═╣╠╦╝╚╗╔╝║║║║  ",
    "  ╩═╝╚═╝╝╚╝╩ ╩╩╚═ ╚╝ ╩╩ ╩  ",
    "",
    "    AI-first terminal workspace    ",
    "",
  }

  dashboard.section.buttons.val = {
    dashboard.button("c", "   Claude Code    new session",
      function() threads.launch_now("claude") end),
    dashboard.button("o", "   Codex          new session",
      function() threads.launch_now("codex") end),
    dashboard.button("t", "   Terminal       new session",
      function() threads.launch_now("terminal") end),
    dashboard.button("r", "   Resume         pick a thread",
      function() threads.pick() end),
    dashboard.button("q", "   Quit",
      "<cmd>qa<cr>"),
  }

  dashboard.section.footer.val     = make_footer()
  dashboard.section.footer.opts.hl = "Comment"

  -- Subtle highlights
  dashboard.section.header.opts.hl  = "Keyword"
  dashboard.section.buttons.opts.hl = "Function"

  alpha.setup(dashboard.opts)
end

return M
