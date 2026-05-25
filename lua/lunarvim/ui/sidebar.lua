local M = {}

local WIDTH = 40

local state = {
  buf       = nil,
  win       = nil,
  line_map  = {},   -- lnr -> { type = "thread"|"project"|"empty", data = ... }
  active_id = nil,
  term_bufs = {},   -- thread_id -> terminal bufnr (in-memory, resets on restart)
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

local function get_all_projects()
  local threads_mod  = require("lunarvim.threads")
  local projects_mod = require("lunarvim.projects")

  local map = {}

  for _, p in ipairs(projects_mod.list()) do
    map[p.path] = { path = p.path, threads = {}, last_active = p.added_at }
  end

  for _, g in ipairs(threads_mod.get_grouped()) do
    if not map[g.project] then
      map[g.project] = { path = g.project, threads = {}, last_active = 0 }
    end
    map[g.project].threads     = g.threads
    map[g.project].last_active = g.threads[1].last_accessed
  end

  local result = {}
  for _, p in pairs(map) do table.insert(result, p) end
  table.sort(result, function(a, b) return a.last_active > b.last_active end)
  return result
end

-- ── Renderer ──────────────────────────────────────────────────────────────────

local function render()
  local threads_mod = require("lunarvim.threads")
  local projects    = get_all_projects()
  local SEP         = "  " .. string.rep("─", WIDTH - 4)

  local lines    = {}
  local line_map = {}
  local hls      = {}

  local function push(line, hl, col_s, col_e)
    lines[#lines + 1] = line
    if hl then hls[#hls + 1] = { #lines, col_s or 0, col_e or -1, hl } end
    return #lines
  end

  push("")
  push("  THREADS", "LvimThreadsHeader")
  push(SEP, "LvimThreadsSep")

  if #projects == 0 then
    push("")
    push("  No projects yet.", "LvimThreadsMuted")
    push("  Press p to add one.", "LvimThreadsMuted")
    push("")
  else
    for _, proj in ipairs(projects) do
      push("")
      local short = vim.fn.fnamemodify(proj.path, ":~")
      if #short > WIDTH - 4 then short = "…" .. short:sub(-(WIDTH - 5)) end
      local header_lnr     = push("  " .. short, "LvimThreadsProject")
      line_map[header_lnr] = { type = "project", data = proj }

      if #proj.threads == 0 then
        local lnr     = push("    no threads — n to start one", "LvimThreadsMuted")
        line_map[lnr] = { type = "empty", data = proj }
      else
        for _, t in ipairs(proj.threads) do
          local tool   = threads_mod.AI_TOOLS[t.ai_tool] or { icon = "?" }
          local active = (state.active_id == t.id) and "●" or " "
          local ts     = time_ago(t.last_accessed)

          local name_budget = WIDTH - 10 - #ts
          local name        = t.name
          if #name > name_budget then name = name:sub(1, name_budget - 1) .. "…" end
          local pad = name_budget - #name

          local line    = string.format("  %s %s  %s%s %s",
            active, tool.icon, name, string.rep(" ", pad), ts)
          local lnr     = push(line)
          line_map[lnr] = { type = "thread", data = t }

          if active == "●" then hls[#hls + 1] = { lnr, 2, 3, "LvimThreadsActive" } end
          hls[#hls + 1] = { lnr, #line - #ts, -1, "LvimThreadsTime" }
        end
      end
    end
  end

  push("")
  push(SEP, "LvimThreadsSep")
  push("  p add proj  ·  n new  ·  <CR> open  ·  d del", "LvimThreadsHint")
  push("")

  return lines, line_map, hls
end

local function apply_highlights(hls)
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(state.buf, NS, h[4], h[1] - 1, h[2], h[3])
  end
end

local function refresh()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local lines, line_map, hls = render()
  state.line_map = line_map
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  apply_highlights(hls)
end

-- ── Cursor helpers ────────────────────────────────────────────────────────────

local function entry_at_cursor()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
  return state.line_map[vim.api.nvim_win_get_cursor(state.win)[1]]
end

local function project_at_cursor()
  local e = entry_at_cursor()
  if not e then return nil end
  if e.type == "project" or e.type == "empty" then return e.data.path end
  if e.type == "thread"                        then return e.data.project end
end

-- ── Terminal panel ────────────────────────────────────────────────────────────

-- Returns the first non-sidebar, non-floating window in the current tab.
function M.get_main_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= state.win and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
  return nil
end

-- Creates a new terminal buffer for thread in win and returns the bufnr.
-- Leaves focus in win (caller is responsible for final focus).
local function create_term(thread, win)
  local tool = require("lunarvim.threads").AI_TOOLS[thread.ai_tool]
  local cmd  = tool and tool.cmd or vim.o.shell

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)

  local opts = {}
  if thread.project and vim.fn.isdirectory(thread.project) == 1 then
    opts.cwd = thread.project
  end

  local ok, job_id = pcall(vim.fn.termopen, cmd, opts)
  if not ok or (type(job_id) == "number" and job_id <= 0) then
    vim.notify("Could not start: " .. tostring(cmd), vim.log.levels.WARN)
    vim.api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  pcall(vim.api.nvim_buf_set_name, buf, thread.name)
  vim.bo[buf].buflisted = false
  return buf
end

-- Opens thread's terminal in the main content window.
-- Ensures the sidebar is open, creates the main window if missing,
-- reuses an existing terminal buffer if one exists for this thread.
function M.open_thread(thread)
  if not M.is_open() then M.open() end

  state.active_id = thread.id
  refresh()

  local main_win = M.get_main_win()
  if not main_win then
    -- Sidebar is the only window; split a panel to its right
    vim.api.nvim_set_current_win(state.win)
    vim.cmd("rightbelow vsplit")
    main_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(state.win)
  end

  local bufnr = state.term_bufs[thread.id]
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(main_win, bufnr)
    vim.api.nvim_set_current_win(main_win)
  else
    -- create_term switches to main_win internally
    bufnr = create_term(thread, main_win)
    if bufnr then state.term_bufs[thread.id] = bufnr end
  end

  vim.cmd("startinsert")
end

-- ── Actions ───────────────────────────────────────────────────────────────────

function M.action_open()
  local e = entry_at_cursor()
  if not e or e.type ~= "thread" then return end
  M.open_thread(e.data)
end

function M.action_new()
  local proj    = project_at_cursor()
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
    -- launch creates the thread record and calls open_thread
    threads.launch(choice.key, nil, proj)
  end)
end

function M.action_add_project()
  vim.ui.input({
    prompt     = "Add project: ",
    default    = vim.fn.getcwd(),
    completion = "dir",
  }, function(path)
    if not path or path == "" then return end
    path = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Not a directory: " .. path, vim.log.levels.WARN)
      return
    end
    require("lunarvim.projects").add(path)
    refresh()
  end)
end

function M.action_rename()
  local e = entry_at_cursor()
  if not e or e.type ~= "thread" then return end
  vim.ui.input({ prompt = "Rename: ", default = e.data.name }, function(name)
    if not name or name == "" then return end
    require("lunarvim.threads").rename(e.data.id, name)
    local bufnr = state.term_bufs[e.data.id]
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_set_name, bufnr, name)
    end
    refresh()
  end)
end

function M.action_delete()
  local e = entry_at_cursor()
  if not e then return end

  if e.type == "thread" then
    local t = e.data
    vim.ui.input({ prompt = 'Delete "' .. t.name .. '"? (y/N): ' }, function(inp)
      if inp and inp:lower() == "y" then
        require("lunarvim.threads").delete(t.id)
        if state.active_id == t.id then state.active_id = nil end
        local bufnr = state.term_bufs[t.id]
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        state.term_bufs[t.id] = nil
        refresh()
      end
    end)

  elseif e.type == "project" or e.type == "empty" then
    local short = vim.fn.fnamemodify(e.data.path, ":~")
    vim.ui.input({ prompt = 'Remove "' .. short .. '" from sidebar? (y/N): ' }, function(inp)
      if inp and inp:lower() == "y" then
        require("lunarvim.projects").remove(e.data.path)
        refresh()
      end
    end)
  end
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
  map("<CR>",  M.action_open,        "Open thread")
  map("o",     M.action_open,        "Open thread")
  map("n",     M.action_new,         "New thread")
  map("p",     M.action_add_project, "Add project")
  map("r",     M.action_rename,      "Rename thread")
  map("d",     M.action_delete,      "Delete thread / remove project")
  map("q",     M.close,              "Close sidebar")
  map("<Esc>", M.close,              "Close sidebar")
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

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern  = tostring(state.win),
    once     = true,
    callback = function() state.win = nil end,
  })

  refresh()

  -- Defer focus so our win wins over any WinEnter autocmds fired by other
  -- plugins (e.g. alpha-nvim recapturing focus on the start screen).
  local win = state.win
  vim.schedule(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
    end
  end)
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

function M.set_active(id)
  state.active_id = id
  if M.is_open() then refresh() end
end

return M
