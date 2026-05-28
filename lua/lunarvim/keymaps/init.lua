local M = {}
local map = require("lunarvim.utils").map

-- Register which-key group labels (standalone groups only; AI group is handled
-- by keymaps/ai.lua so it applies in both standalone and plugin contexts).
local function register_groups()
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if not ok then return end
      wk.add({
        { "<leader>b", group = "Buffers"  },
        { "<leader>E", group = "Explorer" },
        { "<leader>f", group = "Find"     },
        { "<leader>g", group = "Git"      },
        { "<leader>l", group = "LSP"      },
        { "<leader>t", group = "Terminal" },
        { "<leader>u", group = "UI"       },
        { "<leader>w", group = "Windows"  },
        { "<leader>q", group = "Quit"     },
      })
    end,
  })
end

local function editor()
  map("i", "jk", "<Esc>", { desc = "Escape insert mode" })

  map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
  map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
  map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
  map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

  map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
  map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })

  map("v", "<", "<gv", { desc = "Dedent selection" })
  map("v", ">", ">gv", { desc = "Indent selection" })

  map("n", "<A-j>", "<cmd>m .+1<cr>==",  { desc = "Move line down" })
  map("n", "<A-k>", "<cmd>m .-2<cr>==",  { desc = "Move line up" })
  map("v", "<A-j>", ":m '>+1<cr>gv=gv",  { desc = "Move selection down" })
  map("v", "<A-k>", ":m '<-2<cr>gv=gv",  { desc = "Move selection up" })

  map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (respects wrap)" })
  map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (respects wrap)" })

  map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

  map({ "n", "v" }, "<leader>/", "gcc", { desc = "Toggle comment", remap = true })
end

local function find()
  local t = function(cmd) return function() require("telescope.builtin")[cmd]() end end

  map("n", "<leader>ff", t("find_files"),  { desc = "Find files" })
  map("n", "<leader>fg", t("live_grep"),   { desc = "Live grep" })
  map("n", "<leader>fw", t("grep_string"), { desc = "Grep word under cursor" })
  map("n", "<leader>fb", t("buffers"),     { desc = "Find buffers" })
  map("n", "<leader>fh", t("help_tags"),   { desc = "Help tags" })
  map("n", "<leader>fr", t("oldfiles"),    { desc = "Recent files" })
  map("n", "<leader>fk", t("keymaps"),     { desc = "Find keymaps" })
  map("n", "<leader>fc", t("commands"),    { desc = "Commands" })
end

local function explorer()
  map("n", "<leader>E", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })
  map("n", "<leader>O", "<cmd>Neotree reveal<cr>",  { desc = "Reveal file in explorer" })
end

local function terminal()
  map("n", "<leader>tt", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Terminal (horizontal)" })
  map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>",      { desc = "Terminal (float)" })
  map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>",   { desc = "Terminal (vertical)" })

  map("t", "<Esc><Esc>", "<C-\\><C-n>",         { desc = "Exit terminal mode" })
  map("t", "<C-h>",      "<C-\\><C-n><C-w>h",   { desc = "Terminal: move to left window" })
  map("t", "<C-j>",      "<C-\\><C-n><C-w>j",   { desc = "Terminal: move to below window" })
  map("t", "<C-k>",      "<C-\\><C-n><C-w>k",   { desc = "Terminal: move to above window" })
  map("t", "<C-l>",      "<C-\\><C-n><C-w>l",   { desc = "Terminal: move to right window" })

  -- Lose input focus without switching window
  map("t", "<C-q>", "<C-\\><C-n>", { desc = "Exit terminal insert mode" })
end

local function buffers()
  map("n", "<leader>bc", "<cmd>bdelete<cr>",                           { desc = "Close buffer" })
  map("n", "<leader>bC", "<cmd>%bdelete|edit#|bdelete#<cr>",           { desc = "Close all other buffers" })
  map("n", "<leader>bn", "<cmd>bnext<cr>",                             { desc = "Next buffer" })
  map("n", "<leader>bp", "<cmd>bprevious<cr>",                         { desc = "Previous buffer" })
  map("n", "<leader>bl", function() require("telescope.builtin").buffers() end, { desc = "List buffers" })
end

local function windows()
  map("n", "<leader>wv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
  map("n", "<leader>ws", "<cmd>split<cr>",  { desc = "Horizontal split" })
  map("n", "<leader>wc", "<cmd>close<cr>",  { desc = "Close window" })
  map("n", "<leader>w=", "<C-w>=",          { desc = "Equalize windows" })
  map("n", "<leader>wh", "<C-w>h",          { desc = "Focus left window" })
  map("n", "<leader>wj", "<C-w>j",          { desc = "Focus below window" })
  map("n", "<leader>wk", "<C-w>k",          { desc = "Focus above window" })
  map("n", "<leader>wl", "<C-w>l",          { desc = "Focus right window" })
end

local function ui()
  map("n", "<leader>un", "<cmd>set number!<cr>",         { desc = "Toggle line numbers" })
  map("n", "<leader>ur", "<cmd>set relativenumber!<cr>", { desc = "Toggle relative numbers" })
  map("n", "<leader>uw", "<cmd>set wrap!<cr>",           { desc = "Toggle word wrap" })
  map("n", "<leader>us", "<cmd>set spell!<cr>",          { desc = "Toggle spell check" })
  map("n", "<leader>ut", function() require("lunarvim.ui.theme").pick() end, { desc = "Change theme" })
end

local function git()
  local lazygit_term = nil
  map("n", "<leader>gg", function()
    local ok, toggleterm = pcall(require, "toggleterm.terminal")
    if not ok then
      vim.notify("Install toggleterm.nvim for lazygit support", vim.log.levels.WARN)
      return
    end

    local dir  = vim.fn.getcwd()
    local info = require("lunarvim.ui.sidebar").get_active_info()
    if info then
      local thread = require("lunarvim.threads").get(info.id)
      if thread and thread.project and vim.fn.isdirectory(thread.project) == 1 then
        dir = thread.project
      end
    end

    if lazygit_term and lazygit_term.dir ~= dir then lazygit_term = nil end
    if not lazygit_term then
      lazygit_term = toggleterm.Terminal:new({
        cmd        = "lazygit",
        dir        = dir,
        direction  = "float",
        float_opts = {
          border = "rounded",
          width  = math.floor(vim.o.columns * 0.92),
          height = math.floor(vim.o.lines * 0.88),
        },
        on_open  = function() vim.cmd("startinsert!") end,
        on_close = function() lazygit_term = nil end,
      })
    end
    lazygit_term:toggle()
  end, { desc = "Lazygit" })
end

local function quit()
  map("n", "<leader>q", "<cmd>confirm q<cr>",  { desc = "Quit" })
  map("n", "<leader>Q", "<cmd>confirm qa<cr>", { desc = "Quit all" })
  map("n", "<C-q>",     "<cmd>confirm q<cr>",  { desc = "Quit" })
end

-- Standalone-only extras (home dashboard, quick sidebar access)
local function standalone()
  map("n", "<leader>ah", "<cmd>Alpha<cr>", { desc = "Home dashboard" })
end

function M.setup()
  register_groups()
  editor()
  find()
  explorer()
  terminal()
  buffers()
  windows()
  ui()
  git()
  quit()
  standalone()
end

return M
