local M = {}

local terms = {}

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

local function is_local_dir(path)
  return path and vim.fn.isdirectory(path) == 1
end

local function git_root(path)
  if not is_local_dir(path) then return nil end
  local root = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not root[1] or root[1] == "" then return nil end
  return root[1]
end

local function buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then return vim.fn.getcwd() end
  if vim.fn.isdirectory(name) == 1 then return name end
  return vim.fn.fnamemodify(name, ":p:h")
end

local function active_thread_project()
  local ok_sidebar, sidebar = pcall(require, "lunarvim.ui.sidebar")
  if not ok_sidebar then return nil end

  local info = sidebar.get_active_info()
  if not info then return nil end

  local thread = require("lunarvim.threads").get(info.id)
  if not thread or not thread.project then return nil end

  local ssh_host = parse_ssh(thread.project)
  if ssh_host or is_local_dir(thread.project) then return thread.project end
  return nil
end

function M.resolve_dir(opts)
  opts = opts or {}
  if opts.dir and opts.dir ~= "" then return opts.dir end

  local cfg = require("lunarvim.config").get()
  local lazygit_cfg = cfg.lazygit or {}

  if lazygit_cfg.use_active_thread_project ~= false then
    local project = active_thread_project()
    if project then return project end
  end

  return git_root(buffer_dir()) or vim.fn.getcwd()
end

local function lazygit_command(dir)
  local ssh_host, ssh_path = parse_ssh(dir)
  if ssh_host then
    if vim.fn.executable("ssh") ~= 1 then
      vim.notify("Install ssh for remote lazygit support", vim.log.levels.WARN)
      return nil, nil
    end
    local remote = "cd " .. vim.fn.shellescape(ssh_path or "/") .. " && lazygit"
    return "ssh -t " .. vim.fn.shellescape(ssh_host) .. " " .. vim.fn.shellescape(remote), nil
  end

  if vim.fn.executable("lazygit") ~= 1 then
    vim.notify("Install lazygit for git UI support", vim.log.levels.WARN)
    return nil, nil
  end

  return "lazygit", dir
end

local function open_with_toggleterm(cmd, dir, key)
  local ok, toggleterm = pcall(require, "toggleterm.terminal")
  if not ok then return false end

  local term = terms[key]
  if not term then
    term = toggleterm.Terminal:new({
      cmd        = cmd,
      dir        = dir,
      direction  = "float",
      float_opts = {
        border = "rounded",
        width  = math.floor(vim.o.columns * 0.92),
        height = math.floor(vim.o.lines * 0.88),
      },
      on_open = function() vim.cmd("startinsert!") end,
      on_close = function() terms[key] = nil end,
    })
    terms[key] = term
  end

  term:toggle()
  return true
end

local function open_with_terminal(cmd, dir)
  local width  = math.floor(vim.o.columns * 0.92)
  local height = math.floor(vim.o.lines * 0.88)
  local row    = math.floor((vim.o.lines - height) / 2)
  local col    = math.floor((vim.o.columns - width) / 2)
  local buf    = vim.api.nvim_create_buf(false, true)
  local win    = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row      = row,
    col      = col,
    width    = width,
    height   = height,
    border   = "rounded",
    style    = "minimal",
  })

  vim.bo[buf].buflisted = false
  vim.fn.termopen(cmd, dir and { cwd = dir } or {})
  vim.cmd("startinsert")

  vim.keymap.set({ "n", "t" }, "<Esc><Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, silent = true, desc = "Close lazygit" })
end

function M.lazygit(opts)
  opts = opts or {}
  local dir = M.resolve_dir(opts)
  local cmd, cwd = lazygit_command(dir)
  if not cmd then return end

  local key = cmd .. "::" .. (cwd or "")
  if open_with_toggleterm(cmd, cwd, key) then return end
  open_with_terminal(cmd, cwd)
end

local function project_label(path)
  local ssh_host, ssh_path = parse_ssh(path)
  if ssh_host then return ssh_host .. ":" .. (ssh_path or "/") end
  return vim.fn.fnamemodify(path, ":~")
end

function M.pick_project()
  local by_path = {}
  local items = {}

  local function add(path, last_active)
    if not path or path == "" or by_path[path] then return end
    by_path[path] = true
    table.insert(items, { path = path, last_active = last_active or 0 })
  end

  for _, p in ipairs(require("lunarvim.projects").list()) do
    add(p.path, p.added_at)
  end

  for _, group in ipairs(require("lunarvim.threads").get_grouped()) do
    local last = group.threads and group.threads[1] and group.threads[1].last_accessed or 0
    add(group.project, last)
  end

  table.sort(items, function(a, b) return a.last_active > b.last_active end)

  if #items == 0 then
    vim.notify("No saved projects yet.", vim.log.levels.INFO)
    return
  end

  vim.ui.select(items, {
    prompt      = "Lazygit project",
    format_item = function(item) return project_label(item.path) end,
  }, function(choice)
    if choice then M.lazygit({ dir = choice.path }) end
  end)
end

function M.setup(cfg)
  cfg = cfg or require("lunarvim.config").get()
  local lazygit_cfg = cfg.lazygit or {}
  if lazygit_cfg.enabled == false then return end

  vim.api.nvim_create_user_command("LunarvimLazyGit", function()
    M.lazygit()
  end, {})

  vim.api.nvim_create_user_command("LunarvimLazyGitProjects", function()
    M.pick_project()
  end, {})

  if lazygit_cfg.keymap and lazygit_cfg.keymap ~= "" then
    require("lunarvim.utils").map("n", lazygit_cfg.keymap, function()
      M.lazygit()
    end, { desc = "Lazygit" })
  end
end

return M
