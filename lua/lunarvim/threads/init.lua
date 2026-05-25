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

function M.new(name, ai_tool)
  local all = read()
  local thread = {
    id            = tostring(os.time()) .. tostring(math.random(1000, 9999)),
    name          = name,
    ai_tool       = ai_tool,
    created_at    = os.time(),
    last_accessed = os.time(),
  }
  table.insert(all, 1, thread)
  write(all)
  return thread
end

local function open_terminal(ai_tool, thread_name)
  local tool = M.AI_TOOLS[ai_tool]
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

function M.launch(ai_tool)
  local tool = M.AI_TOOLS[ai_tool]
  if not tool then return end
  local default = tool.label .. " — " .. os.date("%b %d, %H:%M")
  vim.ui.input({ prompt = "Thread name: ", default = default }, function(name)
    if not name or name == "" then return end
    M.new(name, ai_tool)
    open_terminal(ai_tool, name)
  end)
end

function M.pick()
  local all = read()
  if #all == 0 then
    vim.notify("No saved threads yet. Start one with <leader>an.", vim.log.levels.INFO)
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
    -- Touch last_accessed before opening
    local threads = read()
    for _, t in ipairs(threads) do
      if t.id == choice.thread.id then
        t.last_accessed = os.time()
        break
      end
    end
    write(threads)
    open_terminal(choice.thread.ai_tool, choice.thread.name)
  end)
end

return M
