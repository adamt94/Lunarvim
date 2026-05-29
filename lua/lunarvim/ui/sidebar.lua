local M = {}

local function get_width()
  return require("lunarvim.config").get().sidebar_width
end

local state = {
  buf       = nil,
  win       = nil,
  line_map  = {},   -- lnr -> { type = "thread"|"project"|"empty", data = ... }
  active_id = nil,
  term_bufs = {},   -- thread_id -> terminal bufnr (in-memory, resets on restart)
  term_jobs = {},   -- thread_id -> job_id (for live/dead status)
  collapsed = {},   -- project_path -> bool
}

-- ── File-tree helpers (Neo-tree / nvim-tree) ──────────────────────────────────

local function is_filetree_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft == "neo-tree" or ft == "NvimTree" then return true end
  end
  return false
end

local function close_filetree()
  if vim.fn.exists(":Neotree") == 2 then
    vim.cmd("Neotree close")
  elseif vim.fn.exists(":NvimTreeClose") == 2 then
    vim.cmd("NvimTreeClose")
  end
end

local function open_filetree()
  if vim.fn.exists(":Neotree") == 2 then
    vim.cmd("Neotree")
  elseif vim.fn.exists(":NvimTreeOpen") == 2 then
    vim.cmd("NvimTreeOpen")
  end
end

-- ── Highlights ────────────────────────────────────────────────────────────────

local NS = vim.api.nvim_create_namespace("lunarvim-threads")

local function setup_highlights()
  vim.api.nvim_set_hl(0, "LvimThreadsHeader",  { link = "Title"        })
  vim.api.nvim_set_hl(0, "LvimThreadsProject", { link = "Directory"    })
  vim.api.nvim_set_hl(0, "LvimThreadsActive",  { link = "DiagnosticOk" })
  vim.api.nvim_set_hl(0, "LvimThreadsTime",    { link = "Comment"      })
  vim.api.nvim_set_hl(0, "LvimThreadsSep",     { link = "NonText"      })
  vim.api.nvim_set_hl(0, "LvimThreadsHint",    { link = "Comment"      })
  vim.api.nvim_set_hl(0, "LvimThreadsMuted",   { link = "Comment"      })
  require("lunarvim.ai.status").setup_highlights()
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Parses SSH project paths. Returns (target, remote_path) or (nil, nil).
-- Accepts:  user@host:/path   host:/path   ssh://user@host/path
local function parse_ssh(path)
  if not path then return nil, nil end
  local target, rpath = path:match("^([^/%s][^:]*):(/[^:]*)$")
  if target and (target:find("@") or not target:find("/")) then
    return target, rpath
  end
  target, rpath = path:match("^ssh://([^/]+)(.*)")
  if target then return target, (rpath ~= "" and rpath or "/") end
  return nil, nil
end

-- Short display label for a project path (local or SSH).
local function fmt_project(path)
  local host, rpath = parse_ssh(path)
  if host then
    local bare  = host:gsub(".*@", "")
    local folder = rpath and vim.fn.fnamemodify(rpath, ":t") or ""
    return bare .. ":" .. (folder ~= "" and folder or bare)
  end
  return vim.fn.fnamemodify(path, ":t")
end

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
  local width       = (state.win and vim.api.nvim_win_is_valid(state.win))
                      and vim.api.nvim_win_get_width(state.win) or get_width()
  local threads_mod = require("lunarvim.threads")
  local projects    = get_all_projects()
  local SEP         = string.rep("─", width - 1)

  local lines    = {}
  local line_map = {}
  local hls      = {}

  local function push(line, hl, col_s, col_e)
    lines[#lines + 1] = line
    if hl then hls[#hls + 1] = { #lines, col_s or 0, col_e or -1, hl } end
    return #lines
  end

  local function char_span(line, start_idx, end_idx)
    return vim.str_byteindex(line, start_idx), vim.str_byteindex(line, end_idx)
  end

  push("")
  push(" THREADS", "LvimThreadsHeader")
  push(SEP, "LvimThreadsSep")

  if #projects == 0 then
    push("")
    push(" No projects yet.", "LvimThreadsMuted")
    push(" Press p to add one.", "LvimThreadsMuted")
    push("")
  else
    for _, proj in ipairs(projects) do
      push("")
      local collapsed   = state.collapsed[proj.path]
      local toggle_icon = collapsed and "▶" or "▼"
      local count_str   = " (" .. #proj.threads .. ")"
      local ssh_host    = parse_ssh(proj.path)
      local short       = fmt_project(proj.path)
      local max_name    = width - 4 - #count_str               -- " ▼ " prefix + count suffix
      if #short > max_name then short = short:sub(1, max_name - 1) .. "…" end
      if ssh_host then short = "" .. short end  -- SSH indicator

      local header_line = " " .. toggle_icon .. " " .. short .. count_str
      local header_lnr  = push(header_line, "LvimThreadsProject")
      line_map[header_lnr] = { type = "project", data = proj }

      if not collapsed then
        if #proj.threads == 0 then
          local lnr     = push("   no threads — press n", "LvimThreadsMuted")
          line_map[lnr] = { type = "empty", data = proj }
        else
          for _, t in ipairs(proj.threads) do
            local tool   = threads_mod.AI_TOOLS[t.ai_tool] or { icon = "?", short_label = "?" }
            local active = (state.active_id == t.id) and "●" or " "
            local ts     = time_ago(t.last_accessed)

            local job_id = state.term_jobs[t.id]
            local status = require("lunarvim.ai.status").for_thread(t, job_id)

            -- format: " ● ◆ icon Label - name…pad ts"
            -- fixed display cols: 1+1+1+1+1+2(icon)+1 = 8, then "Label - " prefix inside name
            local short_label  = tool.short_label or tool.label
            local name_prefix  = short_label .. " - "
            local name_budget  = width - 9 - #ts
            local inner_budget = math.max(4, name_budget - #name_prefix)
            local raw_name     = t.name
            if #raw_name > inner_budget then raw_name = raw_name:sub(1, inner_budget - 1) .. "…" end
            local name = name_prefix .. raw_name
            local pad  = math.max(0, name_budget - #name)

            local line    = string.format(" %s %s %s %s%s %s",
              active, status.icon, tool.icon, name, string.rep(" ", pad), ts)
            local lnr     = push(line)
            line_map[lnr] = { type = "thread", data = t }

            if active == "●" then
              local start_col, end_col = char_span(line, 1, 2)
              hls[#hls + 1] = { lnr, start_col, end_col, "LvimThreadsActive" }
            end
            local start_col, end_col = char_span(line, 3, 4)
            hls[#hls + 1] = { lnr, start_col, end_col, status.hl }
            -- orange icon for Claude Code
            if t.ai_tool == "claude" then
              local ic_s, ic_e = char_span(line, 5, 6)
              hls[#hls + 1] = { lnr, ic_s, ic_e, "LvimThreadsClaudeIcon" }
            elseif t.ai_tool == "copilot" then
              local ic_s, ic_e = char_span(line, 5, 6)
              hls[#hls + 1] = { lnr, ic_s, ic_e, "LvimThreadsCopilotIcon" }
            end
            hls[#hls + 1] = { lnr, #line - #ts, -1, "LvimThreadsTime" }
          end
        end
      end
    end
  end

  push("")

  return lines, line_map, hls
end

local function apply_highlights(hls)
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(state.buf, NS, h[4], h[1] - 1, h[2], h[3])
  end
end

local function cursor_to_active()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
  if not state.active_id then return end
  for lnr, entry in pairs(state.line_map) do
    if entry.type == "thread" and entry.data.id == state.active_id then
      vim.api.nvim_win_set_cursor(state.win, { lnr, 0 })
      return
    end
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

-- Polls ~/.claude/sessions/<pid>.json until sessionId appears, then persists it.
local function capture_session_id(thread_id, job_id, attempt)
  attempt = attempt or 1
  if attempt > 8 then return end
  local pid = vim.fn.jobpid(job_id)
  if not pid or pid <= 0 then return end
  local path = vim.fn.expand("~/.claude/sessions/") .. tostring(pid) .. ".json"
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path)
    if #lines > 0 then
      local ok, data = pcall(vim.json.decode, lines[1])
      if ok and data.sessionId then
        require("lunarvim.threads").set_session_id(thread_id, data.sessionId)
        return
      end
    end
  end
  vim.defer_fn(function() capture_session_id(thread_id, job_id, attempt + 1) end, 1000)
end

local function capture_codex_session_id(thread_id, project, started_at, attempt)
  attempt = attempt or 1
  if attempt > 8 then return end

  local files = vim.fn.glob(vim.fn.expand("~/.codex/sessions/") .. "**/*.jsonl", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)

  for _, file in ipairs(files) do
    if vim.fn.getftime(file) >= started_at - 30 then
      local ok, lines = pcall(vim.fn.readfile, file, "", 20)
      if ok then
        for _, line in ipairs(lines) do
          local ok_json, data = pcall(vim.json.decode, line)
          local payload = ok_json and data and data.payload
          if payload and payload.id and payload.cwd == project then
            require("lunarvim.threads").set_session_id(thread_id, payload.id)
            return
          end
        end
      end
    end
  end

  vim.defer_fn(function()
    capture_codex_session_id(thread_id, project, started_at, attempt + 1)
  end, 1000)
end

local function capture_copilot_session_id(thread_id, started_at, attempt)
  attempt = attempt or 1
  if attempt > 8 then return end

  -- Log files are named session-<uuid>.log and created immediately on start.
  local log_dir = vim.fn.expand("~/.copilot/logs/")
  local files   = vim.fn.glob(log_dir .. "session-*.log", false, true)
  table.sort(files, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)

  for _, file in ipairs(files) do
    if vim.fn.getftime(file) >= started_at - 5 then
      local uuid = vim.fn.fnamemodify(file, ":t"):match("^session%-([%x%-]+)%.log$")
      if uuid then
        require("lunarvim.threads").set_session_id(thread_id, uuid)
        return
      end
    end
  end

  vim.defer_fn(function()
    capture_copilot_session_id(thread_id, started_at, attempt + 1)
  end, 1000)
end

-- Creates a new terminal buffer for thread in win and returns the bufnr.
-- Leaves focus in win (caller is responsible for final focus).
local function create_term(thread, win)
  local tool   = require("lunarvim.threads").AI_TOOLS[thread.ai_tool]
  local ai_cmd = tool and tool.cmd or vim.o.shell

  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)

  local cmd, opts = {}, {}
  local ssh_host, ssh_path = parse_ssh(thread.project)

  if ssh_host then
    local remote = ai_cmd
    if ssh_path and ssh_path ~= "/" then
      remote = "cd " .. vim.fn.shellescape(ssh_path) .. " && " .. ai_cmd
    end
    cmd = { "ssh", "-t", ssh_host, remote }
  else
    -- Direct exec (list form) so jobpid() returns the AI tool's own PID.
    if thread.ai_tool == "claude" then
      cmd = thread.session_id
        and { "claude", "--resume", thread.session_id }
        or  { "claude" }
    elseif thread.ai_tool == "copilot" then
      cmd = thread.session_id
        and { "copilot", "--resume", thread.session_id }
        or  { "copilot" }
    elseif ai_cmd then
      cmd = { ai_cmd }
    else
      cmd = { vim.o.shell }
    end
    if thread.project and vim.fn.isdirectory(thread.project) == 1 then
      opts.cwd = thread.project
    end
  end

  local started_at = os.time()
  local ok, job_id = pcall(vim.fn.termopen, cmd, opts)
  if not ok or (type(job_id) == "number" and job_id <= 0) then
    vim.notify("Could not start: " .. vim.inspect(cmd), vim.log.levels.WARN)
    vim.api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  pcall(vim.api.nvim_buf_set_name, buf, thread.name)
  vim.bo[buf].buflisted      = false
  state.term_jobs[thread.id] = job_id

  -- Capture provider session IDs after start so saved threads can resume later.
  if thread.ai_tool == "claude" and not thread.session_id and not ssh_host then
    vim.defer_fn(function() capture_session_id(thread.id, job_id) end, 1500)
  elseif thread.ai_tool == "codex" and not thread.session_id and not ssh_host then
    vim.defer_fn(function() capture_codex_session_id(thread.id, thread.project, started_at) end, 1500)
  elseif thread.ai_tool == "copilot" and not thread.session_id and not ssh_host then
    vim.defer_fn(function() capture_copilot_session_id(thread.id, started_at) end, 1500)
  end

  local focus_key = require("lunarvim.config").get().terminal_focus_key
  if focus_key and focus_key ~= "" then
    vim.keymap.set("n", focus_key, function()
      require("lunarvim.ui.sidebar").open()
    end, { buffer = buf, silent = true, desc = "Focus thread sidebar" })
  end

  return buf
end

-- Opens thread's terminal in the main content window.
-- If a sidebar (threads or filetree) was already visible, ensures the threads
-- sidebar is shown beside the terminal. If nothing was open, terminal is full screen.
function M.open_thread(thread)
  local filetree_was_open = is_filetree_open()
  local sidebar_was_open  = M.is_open()

  if filetree_was_open then close_filetree() end

  if (filetree_was_open or sidebar_was_open) and not M.is_open() then
    M.open()
  end

  -- Re-fetch from disk so we always have the latest session_id
  local fresh = require("lunarvim.threads").get(thread.id)
  if fresh then thread = fresh end

  state.active_id = thread.id
  refresh()
  cursor_to_active()

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

  vim.schedule(function() vim.cmd("startinsert") end)
end

-- ── Actions ───────────────────────────────────────────────────────────────────

function M.action_open()
  local e = entry_at_cursor()
  if not e or e.type ~= "thread" then return end
  M.open_thread(e.data)
end

function M.action_lazygit()
  local project = project_at_cursor()
  if not project then
    vim.notify("No project under cursor.", vim.log.levels.INFO)
    return
  end
  require("lunarvim.git").lazygit({ dir = project })
end

function M.action_new()
  local proj    = project_at_cursor()
  local threads = require("lunarvim.threads")
  local tools   = {
    { key = "claude",   label = threads.AI_TOOLS.claude.icon   .. "  Claude Code" },
    { key = "codex",    label = threads.AI_TOOLS.codex.icon    .. "  Codex" },
    { key = "copilot",  label = threads.AI_TOOLS.copilot.icon  .. "  GitHub Copilot Chat" },
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

local function add_project_path(path)
  path = path:gsub("/+$", "")
  local ssh_host = parse_ssh(path)
  if ssh_host then
    require("lunarvim.projects").add(path)
    refresh()
  else
    path = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Not a directory: " .. path, vim.log.levels.WARN)
      return
    end
    require("lunarvim.projects").add(path)
    refresh()
  end
end

local function add_project_ssh_input(default)
  vim.ui.input({
    prompt     = "SSH project (user@host:/path): ",
    default    = default or "",
    completion = "dir",
  }, function(path)
    if not path or path == "" then return end
    add_project_path(path)
  end)
end

function M.action_add_project()
  local e = entry_at_cursor()
  local ctx_path
  if e then
    ctx_path = (e.type == "project" or e.type == "empty") and e.data.path
               or (e.type == "thread" and e.data.project)
  end

  local search_root
  if ctx_path and not parse_ssh(ctx_path) then
    search_root = vim.fn.fnamemodify(ctx_path, ":h")
  else
    search_root = vim.fn.expand("~")
  end

  local ok_telescope = pcall(require, "telescope.pickers")
  if ok_telescope then
    local pickers      = require("telescope.pickers")
    local finders      = require("telescope.finders")
    local conf         = require("telescope.config").values
    local actions      = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
      prompt_title = "Add Project  (<C-e> for SSH path)",
      finder = finders.new_oneshot_job({
        "find", search_root,
        "-maxdepth", "5",
        "-type", "d",
        "-not", "-path", "*/\\.git*",
        "-not", "-path", "*/node_modules/*",
        "-not", "-path", "*/\\.cache/*",
      }, {}),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          add_project_path(entry[1])
        end)
        map({ "i", "n" }, "<C-e>", function()
          actions.close(prompt_bufnr)
          add_project_ssh_input()
        end)
        return true
      end,
    }):find()
  else
    vim.ui.input({ prompt = "Project path (or user@host:/path): " }, function(path)
      if not path or path == "" then return end
      add_project_path(path)
    end)
  end
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

local function do_delete(e)
  if e.type == "thread" then
    local t = e.data
    require("lunarvim.threads").delete(t.id)
    if state.active_id == t.id then state.active_id = nil end
    local bufnr = state.term_bufs[t.id]
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    state.term_bufs[t.id] = nil
    state.term_jobs[t.id] = nil
    refresh()
  elseif e.type == "project" or e.type == "empty" then
    local proj_path = e.data.path
    -- clean up all threads for this project
    for _, t in ipairs(e.data.threads or {}) do
      require("lunarvim.threads").delete(t.id)
      if state.active_id == t.id then state.active_id = nil end
      local bufnr = state.term_bufs[t.id]
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
      state.term_bufs[t.id] = nil
      state.term_jobs[t.id] = nil
    end
    require("lunarvim.projects").remove(proj_path)
    refresh()
  end
end

function M.action_delete()
  local e = entry_at_cursor()
  if not e then return end

  if e.type == "thread" then
    vim.ui.input({ prompt = 'Delete "' .. e.data.name .. '"? (y/N): ' }, function(inp)
      if inp and inp:lower() == "y" then do_delete(e) end
    end)
  elseif e.type == "project" or e.type == "empty" then
    local short      = vim.fn.fnamemodify(e.data.path, ":~")
    local n          = #(e.data.threads or {})
    local thread_str = n == 0 and "" or (" and " .. n .. " thread" .. (n == 1 and "" or "s"))
    vim.ui.input({ prompt = 'Remove "' .. short .. '"' .. thread_str .. '? (y/N): ' }, function(inp)
      if inp and inp:lower() == "y" then do_delete(e) end
    end)
  end
end

function M.action_delete_force()
  local e = entry_at_cursor()
  if not e then return end
  do_delete(e)
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
  local function map(lhs, fn, desc, extra)
    vim.keymap.set("n", lhs, fn,
      vim.tbl_extend("force", { buffer = buf, silent = true, nowait = true, desc = desc }, extra or {}))
  end
  map("<CR>", function()
    local e = entry_at_cursor()
    if not e then return end
    if e.type == "thread" then
      M.open_thread(e.data)
    else
      state.collapsed[e.data.path] = not state.collapsed[e.data.path]
      refresh()
    end
  end, "Open thread / toggle project collapse")
  map("o", M.action_open, "Open thread")
  map("G",     M.action_lazygit,      "Lazygit for project")
  map("n",     M.action_new,          "New thread")
  map("a",     M.action_add_project,  "Add project")
  map("p",     M.action_add_project,  "Add project")
  map("r",     M.action_rename,       "Rename thread")
  map("d",     M.action_delete,       "Delete (confirm)",    { nowait = false })
  map("dd",    M.action_delete_force, "Delete (no confirm)")
  map("<C-f>", "G",                    "Go to bottom (see hints)")
  map("q",     M.close,               "Close sidebar")
  map("<Esc>", M.close,               "Close sidebar")
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

  vim.cmd("topleft " .. get_width() .. "vsplit")
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

  vim.api.nvim_create_autocmd("WinEnter", {
    buffer   = state.buf,
    callback = function() cursor_to_active() end,
  })

  vim.api.nvim_create_autocmd("WinResized", {
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then refresh() end
    end,
  })

  refresh()

  -- Defer focus so our win wins over any WinEnter autocmds fired by other
  -- plugins (e.g. alpha-nvim recapturing focus on the start screen).
  local win = state.win
  vim.schedule(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      cursor_to_active()
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

-- Swap the left slot between the threads sidebar and the file tree.
-- Keeps whatever is in the main window (code or AI terminal) untouched.
function M.swap_sidebar()
  if M.is_open() then
    M.close()
    open_filetree()
  elseif is_filetree_open() then
    close_filetree()
    M.open()
  else
    M.open()
  end
end

function M.set_active(id)
  state.active_id = id
  if M.is_open() then refresh() end
end

-- Returns lightweight info about the active thread for status bar use.
function M.get_active_info()
  if not state.active_id then return nil end
  return {
    id     = state.active_id,
    job_id = state.term_jobs[state.active_id],
  }
end

return M
