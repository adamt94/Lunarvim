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
-- Result is an array: { { project = "/path", threads = {...} }, ... }
-- sorted by the most recently touched thread in each group.
function M.get_grouped()
  local all     = read()
  local map     = {}  -- project -> list of threads
  local order   = {}  -- insertion order for projects

  for _, t in ipairs(all) do
    local proj = t.project or "other"
    if not map[proj] then
      map[proj] = {}
      table.insert(order, proj)
    end
    table.insert(map[proj], t)
  end

  -- Sort projects by their most recent thread (all already sorted desc so [1] is latest)
  table.sort(order, function(a, b)
    return map[a][1].last_accessed > map[b][1].last_accessed
  end)

  local result = {}
  for _, proj in ipairs(order) do
    table.insert(result, { project = proj, threads = map[proj] })
  end
  return result
end

function M.new(name, ai_tool)
  local all    = read()
  local thread = {
    id            = tostring(os.time()) .. tostring(math.random(1000, 9999)),
    name          = name,
    ai_tool       = ai_tool,
    project       = vim.fn.getcwd(),
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

function M.open_terminal(ai_tool, thread_name)
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
  Terminal:new(opts):toggle()
end

-- Opens the thread picker (used from keymaps and dashboard).
function M.launch(ai_tool, callback)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  local default = tool.label .. " — " .. os.date("%b %d, %H:%M")
  vim.ui.input({ prompt = "Thread name: ", default = default }, function(name)
    if not name or name == "" then return end
    local thread = M.new(name, ai_tool)
    M.open_terminal(ai_tool, name)
    if callback then callback(thread) end
  end)
end

-- Fuzzy picker over all saved threads (used from <leader>ar and dashboard).
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
    M.open_terminal(choice.thread.ai_tool, choice.thread.name)
  end)
end

return M
