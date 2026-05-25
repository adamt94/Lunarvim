local M = {}

M.AI_TOOLS = {
  claude   = { cmd = "claude", label = "Claude Code", icon = "" },
  codex    = { cmd = "codex",  label = "Codex",       icon = "" },
  terminal = { cmd = nil,      label = "Terminal",     icon = "" },
}

local data_dir     = vim.fn.stdpath("data") .. "/lunarvim"
local threads_path = data_dir .. "/threads.json"

local function read()
  if vim.fn.filereadable(threads_path) == 0 then return {} end
  local lines = vim.fn.readfile(threads_path)
  if #lines == 0 then return {} end
  return vim.json.decode(table.concat(lines, "")) or {}
end

local function write(threads)
  vim.fn.mkdir(data_dir, "p")
  vim.fn.writefile({ vim.json.encode(threads) }, threads_path)
end

-- Returns up to n most recent threads (flat, sorted by last_accessed desc).
function M.recent(n)
  local all = read()
  local result = {}
  for i = 1, math.min(n or 5, #all) do result[i] = all[i] end
  return result
end

-- Returns threads grouped by project folder, each group sorted most-recent first.
function M.get_grouped()
  local all   = read()
  local map   = {}
  local order = {}

  for _, t in ipairs(all) do
    local proj = t.project or "other"
    if not map[proj] then
      map[proj] = {}
      table.insert(order, proj)
    end
    table.insert(map[proj], t)
  end

  table.sort(order, function(a, b)
    return map[a][1].last_accessed > map[b][1].last_accessed
  end)

  local result = {}
  for _, proj in ipairs(order) do
    table.insert(result, { project = proj, threads = map[proj] })
  end
  return result
end

-- project is optional; defaults to cwd. Auto-registers the project.
function M.new(name, ai_tool, project)
  project = project or vim.fn.getcwd()
  require("lunarvim.projects").ensure(project)

  local all    = read()
  local thread = {
    id            = tostring(os.time()) .. tostring(math.random(1000, 9999)),
    name          = name,
    ai_tool       = ai_tool,
    project       = project,
    created_at    = os.time(),
    last_accessed = os.time(),
  }
  table.insert(all, 1, thread)
  write(all)
  return thread
end

function M.rename(id, name)
  local all = read()
  for _, t in ipairs(all) do
    if t.id == id then t.name = name; break end
  end
  write(all)
end

function M.delete(id)
  local all     = read()
  local updated = {}
  for _, t in ipairs(all) do
    if t.id ~= id then table.insert(updated, t) end
  end
  write(updated)
end

-- dir is optional; when supplied the terminal opens in that directory.
function M.open_terminal(ai_tool, thread_name, dir)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  local ok, Terminal = pcall(function() return require("toggleterm.terminal").Terminal end)
  if not ok then
    vim.notify("toggleterm not available", vim.log.levels.ERROR)
    return
  end
  local opts = {
    direction     = "float",
    display_name  = thread_name,
    close_on_exit = false,
    float_opts    = { border = "curved" },
  }
  if tool.cmd then opts.cmd = tool.cmd end
  if dir      then opts.dir = dir end
  Terminal:new(opts):toggle()
end

-- project is optional override (e.g. from sidebar project header).
-- callback receives the created thread object.
function M.launch(ai_tool, callback, project)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  local default = tool.label .. " — " .. os.date("%b %d, %H:%M")
  vim.ui.input({ prompt = "Thread name: ", default = default }, function(name)
    if not name or name == "" then return end
    local thread = M.new(name, ai_tool, project)
    M.open_terminal(ai_tool, name, project)
    if callback then callback(thread) end
  end)
end

-- Fuzzy picker over all saved threads.
function M.pick()
  local all = read()
  if #all == 0 then
    vim.notify("No saved threads yet.", vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, t in ipairs(all) do
    local tool = M.AI_TOOLS[t.ai_tool] or { label = t.ai_tool }
    table.insert(items, {
      thread = t,
      label  = string.format("%-14s  %s", "[" .. tool.label .. "]", t.name),
    })
  end
  vim.ui.select(items, {
    prompt      = "Resume thread",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    local threads = read()
    for _, t in ipairs(threads) do
      if t.id == choice.thread.id then t.last_accessed = os.time(); break end
    end
    write(threads)
    M.open_terminal(choice.thread.ai_tool, choice.thread.name, choice.thread.project)
  end)
end

return M
