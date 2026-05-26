local M = {}
local map = require("lunarvim.utils").map

-- Register which-key group labels so the popup shows clean category names.
-- Deferred to User VeryLazy so which-key is guaranteed to be loaded first.
local function register_groups()
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if not ok then return end
      wk.add({
        { "<leader>b", group = "Buffers" },
        { "<leader>E", group = "Explorer" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>l", group = "LSP" },
        { "<leader>t", group = "Terminal" },
        { "<leader>a", group = "AI" },
        { "<leader>u", group = "UI" },
        { "<leader>w", group = "Windows" },
        { "<leader>q", group = "Quit" },
      })
    end,
  })
end

-- General editor quality-of-life --
local function editor()
  -- Escape aliases
  map("i", "jk", "<Esc>", { desc = "Escape insert mode" })

  -- Window navigation (standard Vim splits feel)
  map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
  map("n", "<C-j>", "<C-w>j", { desc = "Move to below window" })
  map("n", "<C-k>", "<C-w>k", { desc = "Move to above window" })
  map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

  -- Buffer cycling
  map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
  map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })

  -- Visual indent: stay in visual mode after indenting
  map("v", "<", "<gv", { desc = "Dedent selection" })
  map("v", ">", ">gv", { desc = "Indent selection" })

  -- Move lines up/down in visual and normal mode
  map("n", "<A-j>", "<cmd>m .+1<cr>==",        { desc = "Move line down" })
  map("n", "<A-k>", "<cmd>m .-2<cr>==",        { desc = "Move line up" })
  map("v", "<A-j>", ":m '>+1<cr>gv=gv",        { desc = "Move selection down" })
  map("v", "<A-k>", ":m '<-2<cr>gv=gv",        { desc = "Move selection up" })

  -- Better up/down on wrapped lines
  map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (respects wrap)" })
  map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (respects wrap)" })

  -- Clear search highlights
  map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

  -- Comment toggle (Comment.nvim uses gcc/gc, this adds leader shortcut)
  map({ "n", "v" }, "<leader>/", "gcc", { desc = "Toggle comment", remap = true })
end

-- Find / Telescope --
local function find()
  local t = function(cmd) return function() require("telescope.builtin")[cmd]() end end

  map("n", "<leader>ff", t("find_files"),              { desc = "Find files" })
  map("n", "<leader>fg", t("live_grep"),               { desc = "Live grep" })
  map("n", "<leader>fw", t("grep_string"),             { desc = "Grep word under cursor" })
  map("n", "<leader>fb", t("buffers"),                 { desc = "Find buffers" })
  map("n", "<leader>fh", t("help_tags"),               { desc = "Help tags" })
  map("n", "<leader>fr", t("oldfiles"),                { desc = "Recent files" })
  map("n", "<leader>fk", t("keymaps"),                 { desc = "Find keymaps" })
  map("n", "<leader>fc", t("commands"),                { desc = "Commands" })
end

-- Explorer / Neo-tree --
local function explorer()
  map("n", "<leader>E",  "<cmd>Neotree toggle<cr>",           { desc = "Toggle file explorer" })
  map("n", "<leader>O",  "<cmd>Neotree reveal<cr>",           { desc = "Reveal file in explorer" })
end

-- Terminal / Toggleterm --
local function terminal()
  map("n", "<leader>tt", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Terminal (horizontal)" })
  map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>",      { desc = "Terminal (float)" })
  map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>",   { desc = "Terminal (vertical)" })

  -- Exit terminal mode without reaching for Ctrl-\
  map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
  map("t", "<C-h>",      "<C-\\><C-n><C-w>h", { desc = "Terminal: move to left window" })
  map("t", "<C-j>",      "<C-\\><C-n><C-w>j", { desc = "Terminal: move to below window" })
  map("t", "<C-k>",      "<C-\\><C-n><C-w>k", { desc = "Terminal: move to above window" })
  map("t", "<C-l>",      "<C-\\><C-n><C-w>l", { desc = "Terminal: move to right window" })

  -- Single-key terminal escapes — nvim intercepts these before Claude Code / Codex.
  -- <C-\>-prefixed chords don't work as t-mode map LHS; plain keys do.

  -- <C-q>: lose input focus, stay in the terminal window (then use <C-h/j/k/l> to move)
  map("t", "<C-q>", "<C-\\><C-n>", { desc = "Exit terminal insert mode" })

  -- <C-f>: lose input focus and jump straight to the thread sidebar
  map("t", "<C-f>", function()
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    vim.schedule(function() require("lunarvim.ui.sidebar").open() end)
  end, { desc = "Exit terminal and focus sidebar" })
end

-- Buffer management --
local function buffers()
  map("n", "<leader>bc", "<cmd>bdelete<cr>",              { desc = "Close buffer" })
  map("n", "<leader>bC", "<cmd>%bdelete|edit#|bdelete#<cr>", { desc = "Close all other buffers" })
  map("n", "<leader>bn", "<cmd>bnext<cr>",                { desc = "Next buffer" })
  map("n", "<leader>bp", "<cmd>bprevious<cr>",            { desc = "Previous buffer" })
  map("n", "<leader>bl", function() require("telescope.builtin").buffers() end, { desc = "List buffers" })
end

-- Window splits --
local function windows()
  map("n", "<leader>wv", "<cmd>vsplit<cr>",  { desc = "Vertical split" })
  map("n", "<leader>ws", "<cmd>split<cr>",   { desc = "Horizontal split" })
  map("n", "<leader>wc", "<cmd>close<cr>",   { desc = "Close window" })
  map("n", "<leader>w=", "<C-w>=",           { desc = "Equalize windows" })
  map("n", "<leader>wh", "<C-w>h",           { desc = "Focus left window" })
  map("n", "<leader>wj", "<C-w>j",           { desc = "Focus below window" })
  map("n", "<leader>wk", "<C-w>k",           { desc = "Focus above window" })
  map("n", "<leader>wl", "<C-w>l",           { desc = "Focus right window" })
end

-- UI toggles --
local function ui()
  map("n", "<leader>un", "<cmd>set number!<cr>",         { desc = "Toggle line numbers" })
  map("n", "<leader>ur", "<cmd>set relativenumber!<cr>", { desc = "Toggle relative numbers" })
  map("n", "<leader>uw", "<cmd>set wrap!<cr>",           { desc = "Toggle word wrap" })
  map("n", "<leader>us", "<cmd>set spell!<cr>",          { desc = "Toggle spell check" })
end

-- AI sessions --
local function ai()
  map("n", "<leader>e",  function() require("lunarvim.ui.sidebar").toggle() end,        { desc = "Toggle thread sidebar" })
  map("n", "<leader>o",  function() require("lunarvim.ui.sidebar").open() end,          { desc = "Focus thread sidebar" })
  map("n", "<leader>as", function() require("lunarvim.ui.sidebar").toggle() end,        { desc = "Toggle thread sidebar" })
  map("n", "<leader>an", function() require("lunarvim.threads").launch("claude") end,   { desc = "New Claude session" })
  map("n", "<leader>ao", function() require("lunarvim.threads").launch("codex") end,    { desc = "New Codex session" })
  map("n", "<leader>ap", function() require("lunarvim.threads").launch("copilot") end,  { desc = "New Copilot Chat session" })
  map("n", "<leader>at", function() require("lunarvim.threads").launch("terminal") end, { desc = "New terminal session" })
  map("n", "<leader>ar", function() require("lunarvim.threads").pick() end,             { desc = "Resume thread" })
  map("n", "<leader>ah", "<cmd>Alpha<cr>",                                              { desc = "Home dashboard" })
end

-- Git --
local function git()
  map("n", "<leader>gg", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ui  = vim.api.nvim_list_uis()[1]
    local w   = math.floor(ui.width  * 0.92)
    local h   = math.floor(ui.height * 0.88)
    local row = math.floor((ui.height - h) / 2)
    local col = math.floor((ui.width  - w) / 2)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", style = "minimal", border = "rounded",
      width = w, height = h, row = row, col = col,
    })
    vim.api.nvim_set_current_win(win)
    vim.fn.termopen("lazygit", {
      on_exit = function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      end,
    })
    vim.cmd("startinsert")
  end, { desc = "Lazygit" })
end

-- Quit --
local function quit()
  map("n", "<leader>q",  "<cmd>confirm q<cr>",  { desc = "Quit" })
  map("n", "<leader>Q",  "<cmd>confirm qa<cr>", { desc = "Quit all" })
  map("n", "<C-q>",      "<cmd>confirm q<cr>",  { desc = "Quit" })
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
  ai()
  git()
  quit()
end

return M
