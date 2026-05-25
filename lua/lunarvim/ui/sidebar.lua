local M = {}

local WIDTH = 40

local state = {
  buf        = nil,   -- scratch buffer handle (reused across open/close)
  win        = nil,   -- window handle (nil when closed)
  thread_map = {},    -- line_nr (1-indexed) -> thread object
  active_id  = nil,   -- id of the thread whose terminal is currently open
}

-- ── Highlights ────────────────────────────────────────────────────────────────

local NS = vim.api.nvim_create_namespace("lunarvim-threads")

local function setup_highlights()
  vim.api.nvim_set_hl(0, "LvimThreadsHeader",  { link = "Title",        default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsProject", { link = "Directory",    default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsActive",  { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsTime",    { link = "Comment",      default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsSep",     { link = "NonText",      default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsHint",    { link = "Comment",      default = true })
  vim.api.nvim_set_hl(0, "LvimThreadsMuted",   { link = "Comment",      default = true })
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function time_ago(ts)
  local d = os.difftime(os.time(), ts)
  if d < 3600  then return math.floor(d / 60) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  return math.floor(d / 86400) .. "d"
end

-- ── Renderer ──────────────────────────────────────────────────────────────────

local function render()
  local threads = require("lunarvim.threads")
  local grouped = threads.get_grouped()
  local SEP     = "  " .. string.rep("─", WIDTH - 4)

  local lines      = {}
  local thread_map = {}
  local hls        = {}  -- { lnr, col_start, col_end, hl_group }

  local function push(line, hl, col_s, col_e)
    lines[#lines + 1] = line
    if hl then
      hls[#hls + 1] = { #lines, col_s or 0, col_e or -1, hl }
    end
    return #lines
  end

  push("")
  push("  THREADS", "LvimThreadsHeader")
  push(SEP, "LvimThreadsSep")

  if #grouped == 0 then
    push("")
    push("  No threads yet.", "LvimThreadsMuted")
    push("  Press n to start one.", "LvimThreadsMuted")
    push("")
  else
    for _, group in ipairs(grouped) do
      push("")
      local short = vim.fn.fnamemodify(group.project, ":~")
      push("  " .. short, "LvimThreadsProject")

      for _, t in ipairs(group.threads) do
        local tool   = threads.AI_TOOLS[t.ai_tool] or { icon = "?" }
        local active = (state.active_id == t.id) and "●" or " "
        local ts     = time_ago(t.last_accessed)

        -- Budget: 2 indent + 1 active + 1 space + icon(varies) + 2 space + name + pad + ts
        -- Keep it simple: fixed columns
        local name_budget = WIDTH - 10 - #ts
        local name = t.name
        if #name > name_budget then name = name:sub(1, name_budget - 1) .. "…" end
        local pad  = name_budget - #name

        local line = string.format("  %s %s  %s%s %s",
          active, tool.icon, name, string.rep(" ", pad), ts)

        local lnr       = push(line)
        thread_map[lnr] = t

        if active == "●" then hls[#hls + 1] = { lnr, 2, 3, "LvimThreadsActive" } end
        -- Dim the timestamp (rightmost #ts chars)
        local ts_start = #line - #ts
        hls[#hls + 1] = { lnr, ts_start, -1, "LvimThreadsTime" }
      end
    end
  end

  push("")
  push(SEP, "LvimThreadsSep")
  push("  n new · <CR> open · r rename · d del", "LvimThreadsHint")
  push("")

  return lines, thread_map, hls
end

local function apply_highlights(hls)
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, h in ipairs(hls) do
    -- h = { lnr (1-indexed), col_start, col_end, hl_group }
    vim.api.nvim_buf_add_highlight(state.buf, NS, h[4], h[1] - 1, h[2], h[3])
  end
end

local function refresh()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local lines, thread_map, hls = render()
  state.thread_map = thread_map
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  apply_highlights(hls)
end

-- ── Cursor helpers ────────────────────────────────────────────────────────────

local function thread_at_cursor()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.thread_map[row]
end

-- ── Actions ───────────────────────────────────────────────────────────────────

function M.action_open()
  local t = thread_at_cursor()
  if not t then return end
  state.active_id = t.id
  refresh()
  require("lunarvim.threads").open_terminal(t.ai_tool, t.name)
end

function M.action_new()
  local threads = require("lunarvim.threads")
  local tools   = {
    { key = "claude",   label = threads.AI_TOOLS.claude.icon   .. "  Claude Code" },
    { key = "codex",    label = threads.AI_TOOLS.codex.icon    .. "  Codex" },
    { key = "terminal", label = threads.AI_TOOLS.terminal.icon .. "  Terminal" },
  }
  vim.ui.select(tools, {
    prompt      = "AI tool:",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    threads.launch(choice.key, function(thread)
      state.active_id = thread.id
      refresh()
    end)
  end)
end

function M.action_rename()
  local t = thread_at_cursor()
  if not t then return end
  vim.ui.input({ prompt = "Rename: ", default = t.name }, function(name)
    if not name or name == "" then return end
    require("lunarvim.threads").rename(t.id, name)
    refresh()
  end)
end

function M.action_delete()
  local t = thread_at_cursor()
  if not t then return end
  vim.ui.input({ prompt = 'Delete "' .. t.name .. '"? (y/N): ' }, function(input)
    if input and input:lower() == "y" then
      require("lunarvim.threads").delete(t.id)
      if state.active_id == t.id then state.active_id = nil end
      refresh()
    end
  end)
end

-- ── Buffer setup ──────────────────────────────────────────────────────────────

local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype   = "lunarvim-threads"
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].swapfile   = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].buflisted  = false
  return buf
end

local function set_keymaps(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn,
      { buffer = buf, silent = true, nowait = true, desc = desc })
  end
  map("<CR>",  M.action_open,   "Open thread")
  map("o",     M.action_open,   "Open thread")
  map("n",     M.action_new,    "New thread")
  map("r",     M.action_rename, "Rename thread")
  map("d",     M.action_delete, "Delete thread")
  map("q",     M.close,         "Close sidebar")
  map("<Esc>", M.close,         "Close sidebar")
end

-- ── Window management ─────────────────────────────────────────────────────────

function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  setup_highlights()

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = create_buf()
    set_keymaps(state.buf)
  end

  -- Left vertical split
  vim.cmd("topleft " .. WIDTH .. "vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  local wo = vim.wo[state.win]
  wo.number         = false
  wo.relativenumber = false
  wo.signcolumn     = "no"
  wo.wrap           = false
  wo.cursorline     = true
  wo.winfixwidth    = true

  -- Detect manual close (user presses :q / <C-w>c inside the panel)
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern  = tostring(state.win),
    once     = true,
    callback = function() state.win = nil end,
  })

  refresh()
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  end
end

function M.toggle()
  if M.is_open() then M.close() else M.open() end
end

-- Called by threads.launch so the active indicator updates after a terminal opens.
function M.set_active(id)
  state.active_id = id
  if M.is_open() then refresh() end
end

return M
