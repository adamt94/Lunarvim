local M = {}

local CLAUDE_LIVE_DIR = vim.fn.expand("~/.claude/sessions/")
local CLAUDE_PROJECTS_DIR = vim.fn.expand("~/.claude/projects/")
local CLAUDE_SETTINGS_PATH = vim.fn.expand("~/.claude/settings.json")
local CODEX_SESSIONS_DIR = vim.fn.expand("~/.codex/sessions/")

M.colors = {
  blue    = "#89b4fa",
  green   = "#a6e3a1",
  mauve   = "#cba6f7",
  overlay = "#6c7086",
  peach   = "#fab387",
  red     = "#f38ba8",
  surface = "#585b70",
  yellow  = "#f9e2af",
}

M.states = {
  busy    = { icon = "●", label = "working",  hl = "LvimThreadsBusy",    color = M.colors.yellow },
  done    = { icon = "✓", label = "finished", hl = "LvimThreadsDone",    color = M.colors.green },
  idle    = { icon = "◆", label = "idle",     hl = "LvimThreadsIdle",    color = M.colors.blue },
  running = { icon = "▶", label = "running",  hl = "LvimThreadsRunning", color = M.colors.mauve },
  stopped = { icon = "■", label = "stopped",  hl = "LvimThreadsStopped", color = M.colors.red },
  unknown = { icon = "?", label = "unknown",  hl = "LvimThreadsUnknown", color = M.colors.overlay },
}

local EFFORT_ICONS = { low = "▁", medium = "▄", high = "█", max = "▇" }

local MODEL_SHORT = {
  ["claude-opus-4-7"]           = "opus",
  ["claude-opus-4-6"]           = "opus",
  ["claude-sonnet-4-6"]         = "sonnet",
  ["claude-haiku-4-5-20251001"] = "haiku",
  ["claude-haiku-4-5"]          = "haiku",
  ["gpt-5.5"]                   = "gpt-5.5",
  ["gpt-5"]                     = "gpt-5",
}

local cache = {
  claude_live = nil,
  claude_live_at = 0,
  claude_settings = nil,
  codex_files = nil,
  codex_files_at = 0,
  meta = {},
}

local function read_json(path)
  if vim.fn.filereadable(path) == 0 then return nil end
  local lines = vim.fn.readfile(path)
  if #lines == 0 then return nil end
  local ok, data = pcall(vim.json.decode, table.concat(lines, ""))
  return ok and data or nil
end

local function decode_line(line)
  if not line or line == "" then return nil end
  local ok, data = pcall(vim.json.decode, line)
  return ok and data or nil
end

local function value_or_nil(value)
  if value == vim.NIL then return nil end
  return value
end

local function read_tail(path, max)
  if vim.fn.filereadable(path) == 0 then return {} end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return {} end
  if #lines <= max then return lines end
  local tail = {}
  for i = #lines - max + 1, #lines do tail[#tail + 1] = lines[i] end
  return tail
end

local function job_alive(job_id)
  return job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function pid_alive(pid)
  if not pid then return false end
  return pcall(vim.uv.kill, pid, 0)
end

local function short_model(model)
  if not model then return nil end
  return MODEL_SHORT[model] or model:gsub("^claude%-", ""):gsub("%-20%d%d%d%d%d%d%d%d$", "")
end

local function fmt_tokens(n)
  if not n then return nil end
  if n >= 1000000 then return string.format("%.1fm tok", n / 1000000) end
  if n >= 1000 then return string.format("%.1fk tok", n / 1000) end
  return tostring(n) .. " tok"
end

local function project_key(path)
  return path and path:gsub("/", "-") or nil
end

local function claude_live_sessions()
  local now = os.time()
  if cache.claude_live and now - cache.claude_live_at < 2 then return cache.claude_live end

  local sessions = {}
  for _, file in ipairs(vim.fn.glob(CLAUDE_LIVE_DIR .. "*.json", false, true)) do
    local data = read_json(file)
    if data and data.pid and pid_alive(data.pid) then sessions[#sessions + 1] = data end
  end

  cache.claude_live = sessions
  cache.claude_live_at = now
  return sessions
end

local function claude_settings()
  if cache.claude_settings then return cache.claude_settings end
  cache.claude_settings = read_json(CLAUDE_SETTINGS_PATH) or {}
  return cache.claude_settings
end

local function find_claude_jsonl(thread)
  if thread.session_id then
    local by_id = vim.fn.glob(CLAUDE_PROJECTS_DIR .. "**/" .. thread.session_id .. ".jsonl", false, true)
    if #by_id > 0 then return by_id[1] end
  end

  local dir = project_key(thread.project)
  if not dir then return nil end
  local files = vim.fn.glob(CLAUDE_PROJECTS_DIR .. dir .. "/*.jsonl", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
  return files[1]
end

local function codex_files()
  local now = os.time()
  if cache.codex_files and now - cache.codex_files_at < 2 then return cache.codex_files end
  local files = vim.fn.glob(CODEX_SESSIONS_DIR .. "**/*.jsonl", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
  cache.codex_files = files
  cache.codex_files_at = now
  return files
end

local function find_codex_jsonl(thread)
  for _, file in ipairs(codex_files()) do
    if thread.session_id and file:find(thread.session_id, 1, true) then return file end
  end

  for _, file in ipairs(codex_files()) do
    for _, line in ipairs(read_tail(file, 40)) do
      local data = decode_line(line)
      local payload = data and data.payload
      if payload and payload.cwd == thread.project then return file end
    end
  end
end

local function usage_total(usage)
  if not usage then return nil end
  local total = (usage.input_tokens or 0)
    + (usage.cache_creation_input_tokens or 0)
    + (usage.cache_read_input_tokens or 0)
    + (usage.output_tokens or 0)
  return total > 0 and total or nil
end

local function claude_meta(thread)
  local file = find_claude_jsonl(thread)
  if not file then return {} end
  local key = "claude:" .. file .. ":" .. tostring(vim.fn.getftime(file)) .. ":" .. tostring(vim.fn.getfsize(file))
  if cache.meta[key] then return cache.meta[key] end

  local meta = { provider = "claude" }
  local seen = {}
  local total = 0
  for _, line in ipairs(read_tail(file, 300)) do
    local data = decode_line(line)
    local msg = data and data.message
    if msg and msg.role == "assistant" then
      meta.model = msg.model or meta.model
      meta.stop_reason = msg.stop_reason or meta.stop_reason
      if msg.usage and msg.id and not seen[msg.id] then
        seen[msg.id] = true
        total = total + (usage_total(msg.usage) or 0)
        meta.last_tokens = usage_total(msg.usage) or meta.last_tokens
      end
    elseif data and data.type == "last-prompt" then
      meta.last_prompt = data.lastPrompt
    end
  end
  meta.tokens = total > 0 and total or meta.last_tokens

  cache.meta[key] = meta
  return meta
end

local function codex_meta(thread)
  local file = find_codex_jsonl(thread)
  if not file then return {} end
  local key = "codex:" .. file .. ":" .. tostring(vim.fn.getftime(file)) .. ":" .. tostring(vim.fn.getfsize(file))
  if cache.meta[key] then return cache.meta[key] end

  local meta = { provider = "codex" }
  for _, line in ipairs(read_tail(file, 300)) do
    local data = decode_line(line)
    if data and data.type == "turn_context" and data.payload then
      meta.model = value_or_nil(data.payload.model) or meta.model
      local settings = data.payload.collaboration_mode and data.payload.collaboration_mode.settings
      meta.effort = value_or_nil(data.payload.reasoning_effort)
        or value_or_nil(settings and settings.reasoning_effort)
        or meta.effort
    elseif data and data.type == "event_msg" and data.payload and data.payload.type == "token_count" then
      local info = data.payload.info or {}
      local usage = info.total_token_usage or {}
      meta.tokens = usage.total_tokens or meta.tokens
      meta.context_window = info.model_context_window or meta.context_window
    elseif data and data.type == "response_item" and data.payload then
      meta.last_response_type = data.payload.type or meta.last_response_type
      if data.payload.type == "message" and data.payload.role == "assistant" then
        meta.stop_reason = "end_turn"
      elseif data.payload.type == "function_call" or data.payload.type == "reasoning" then
        meta.stop_reason = "tool_use"
      end
    end
  end

  cache.meta[key] = meta
  return meta
end

local function provider_meta(thread)
  if thread.ai_tool == "claude" then return claude_meta(thread) end
  if thread.ai_tool == "codex" then return codex_meta(thread) end
  return {}
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "LvimThreadsBusy",    { fg = M.colors.yellow,  default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsDone",    { fg = M.colors.green,   default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsIdle",    { fg = M.colors.blue,    default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsRunning", { fg = M.colors.mauve,   default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsStopped", { fg = M.colors.red,     default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsUnknown", { fg = M.colors.overlay, default = true })
end

function M.for_thread(thread, job_id)
  local alive = job_alive(job_id)
  local meta = provider_meta(thread)
  local state = meta.stop_reason == "end_turn" and "done" or "stopped"

  if alive then
    state = "running"
    if thread.ai_tool == "claude" then
      for _, session in ipairs(claude_live_sessions()) do
        if session.cwd == thread.project or session.sessionId == thread.session_id then
          state = session.status == "busy" and "busy" or "idle"
          break
        end
      end
    end

    if state == "running" then
      if meta.stop_reason == "tool_use" then
        state = "busy"
      elseif meta.stop_reason == "end_turn" then
        state = "done"
      end
    end
  end

  local def = M.states[state] or M.states.unknown
  local effort = meta.effort
  if thread.ai_tool == "claude" then effort = effort or claude_settings().effortLevel end

  return vim.tbl_extend("force", {
    alive = alive,
    model = short_model(meta.model),
    effort = effort,
    tokens = meta.tokens,
    tokens_label = fmt_tokens(meta.tokens),
  }, def)
end

function M.context_for_thread(thread)
  local meta = provider_meta(thread)
  local parts = {}
  local model = short_model(meta.model)
  local effort = meta.effort
  if thread.ai_tool == "claude" then effort = effort or claude_settings().effortLevel end
  if model then parts[#parts + 1] = model end
  if effort then parts[#parts + 1] = (EFFORT_ICONS[effort] or "?") .. " " .. effort end
  local tokens = fmt_tokens(meta.tokens)
  if tokens then parts[#parts + 1] = tokens end
  return table.concat(parts, " ")
end

return M
