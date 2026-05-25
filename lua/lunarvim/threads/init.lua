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

function M.recent(n)
  local all = read()
  local result = {}
  for i = 1, math.min(n or 5, #all) do result[i] = all[i] end
  return result
end

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

-- Returns a short default name: "foldername #N" where N is thread count in project.
local function default_name(project)
  project = project or vim.fn.getcwd()
  local all   = read()
  local count = 0
  for _, t in ipairs(all) do
    if t.project == project then count = count + 1 end
  end
  local folder = vim.fn.fnamemodify(project, ":t")
  return folder .. " #" .. (count + 1)
end

-- project is optional override. callback receives the created thread object.
function M.launch(ai_tool, callback, project)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  project = project or vim.fn.getcwd()
  vim.ui.input({ prompt = "Thread name: ", default = default_name(project) }, function(name)
    if not name or name == "" then return end
    local thread = M.new(name, ai_tool, project)
    require("lunarvim.ui.sidebar").open_thread(thread)
    if callback then callback(thread) end
  end)
end

-- Like launch but skips the name prompt, using the default name immediately.
-- Defers via vim.schedule so callers (e.g. alpha dashboard) can close first.
function M.launch_now(ai_tool, project)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  project      = project or vim.fn.getcwd()
  local thread = M.new(default_name(project), ai_tool, project)
  vim.schedule(function()
    require("lunarvim.ui.sidebar").open_thread(thread)
  end)
end

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
    require("lunarvim.ui.sidebar").open_thread(choice.thread)
  end)
end

return M
