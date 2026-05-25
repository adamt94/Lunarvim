local M = {}

local data_dir      = vim.fn.stdpath("data") .. "/lunarvim"
local projects_path = data_dir .. "/projects.json"

local function read()
  if vim.fn.filereadable(projects_path) == 0 then return {} end
  local lines = vim.fn.readfile(projects_path)
  if #lines == 0 then return {} end
  return vim.json.decode(table.concat(lines, "")) or {}
end

local function write(projects)
  vim.fn.mkdir(data_dir, "p")
  vim.fn.writefile({ vim.json.encode(projects) }, projects_path)
end

local function normalize(path)
  return vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
end

function M.list()
  return read()
end

function M.add(path)
  path    = normalize(path)
  local all = read()
  for _, p in ipairs(all) do
    if p.path == path then return end
  end
  table.insert(all, 1, { path = path, added_at = os.time() })
  write(all)
end

-- Called by threads.new to silently register the project if not already tracked.
M.ensure = M.add

function M.remove(path)
  path    = normalize(path)
  local all     = read()
  local updated = {}
  for _, p in ipairs(all) do
    if p.path ~= path then table.insert(updated, p) end
  end
  write(updated)
end

return M
