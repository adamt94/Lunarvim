-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │  Theme config — this is the only file you need to edit to change theme.  │
-- └──────────────────────────────────────────────────────────────────────────┘

local M = {}

-- ── User settings ─────────────────────────────────────────────────────────────

M.colorscheme = "catppuccin"
M.variant     = "mocha"   -- catppuccin: "latte" | "frappe" | "macchiato" | "mocha"
                           -- tokyonight: "night" | "storm" | "moon" | "day"

-- ── Available themes (shown in the <leader>ut picker) ─────────────────────────

M.options = {
  { label = "Catppuccin Mocha",      colorscheme = "catppuccin", variant = "mocha"      },
  { label = "Catppuccin Macchiato",  colorscheme = "catppuccin", variant = "macchiato"  },
  { label = "Catppuccin Frappe",     colorscheme = "catppuccin", variant = "frappe"     },
  { label = "Catppuccin Latte",      colorscheme = "catppuccin", variant = "latte"      },
  { label = "Tokyo Night",           colorscheme = "tokyonight", variant = "night"      },
  { label = "Tokyo Night Storm",     colorscheme = "tokyonight", variant = "storm"      },
  { label = "Tokyo Night Moon",      colorscheme = "tokyonight", variant = "moon"       },
  { label = "Tokyo Night Day",       colorscheme = "tokyonight", variant = "day"        },
}

-- ── Per-theme palettes ────────────────────────────────────────────────────────

local palettes = {
  ["catppuccin-latte"]     = { yellow = "#df8e1d", green = "#40a02b", blue = "#1e66f5", mauve = "#8839ef", red = "#d20f39", overlay = "#9ca0b0", peach = "#fe640b", surface = "#ccd0da" },
  ["catppuccin-frappe"]    = { yellow = "#e5c890", green = "#a6d189", blue = "#8caaee", mauve = "#ca9ee6", red = "#e78284", overlay = "#737994", peach = "#ef9f76", surface = "#51576d" },
  ["catppuccin-macchiato"] = { yellow = "#eed49f", green = "#a6da95", blue = "#8aadf4", mauve = "#c6a0f6", red = "#ed8796", overlay = "#6e738d", peach = "#f5a97f", surface = "#494d64" },
  ["catppuccin-mocha"]     = { yellow = "#f9e2af", green = "#a6e3a1", blue = "#89b4fa", mauve = "#cba6f7", red = "#f38ba8", overlay = "#6c7086", peach = "#fab387", surface = "#585b70" },

  ["tokyonight-night"] = { yellow = "#e0af68", green = "#9ece6a", blue = "#7aa2f7", mauve = "#bb9af7", red = "#f7768e", overlay = "#565f89", peach = "#ff9e64", surface = "#3b4261" },
  ["tokyonight-storm"] = { yellow = "#e0af68", green = "#9ece6a", blue = "#7aa2f7", mauve = "#bb9af7", red = "#f7768e", overlay = "#565f89", peach = "#ff9e64", surface = "#3b4261" },
  ["tokyonight-moon"]  = { yellow = "#ff966c", green = "#c3e88d", blue = "#82aaff", mauve = "#c099ff", red = "#ff757f", overlay = "#636da6", peach = "#ff966c", surface = "#2f334d" },
  ["tokyonight-day"]   = { yellow = "#8c6c3e", green = "#485e30", blue = "#2e7de9", mauve = "#7847bd", red = "#f52a65", overlay = "#848cb5", peach = "#b15c00", surface = "#e9e9ed" },
  -- ["gruvbox"]        = { ... },
}

local lualine_themes = {
  catppuccin = "catppuccin",
  tokyonight = "tokyonight",
  gruvbox    = "gruvbox",
  kanagawa   = "kanagawa",
  nightfox   = "nightfox",
}

-- ── Persistence ───────────────────────────────────────────────────────────────

local override_path = vim.fn.stdpath("data") .. "/lunarvim/theme.json"

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(override_path, ":h"), "p")
  vim.fn.writefile(
    { vim.json.encode({ colorscheme = M.colorscheme, variant = M.variant }) },
    override_path)
end

local function load_saved()
  if vim.fn.filereadable(override_path) == 0 then return end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(override_path), ""))
  if ok and data and data.colorscheme then
    M.colorscheme = data.colorscheme
    M.variant     = data.variant or M.variant
  end
end

-- ── Runtime helpers ───────────────────────────────────────────────────────────

local function hl_fg(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl.fg then return string.format("#%06x", hl.fg) end
end

function M.colors()
  local versioned = { catppuccin = true, tokyonight = true }
  local key = versioned[M.colorscheme]
    and (M.colorscheme .. "-" .. (M.variant or ""))
    or M.colorscheme

  if palettes[key] then return palettes[key] end

  return {
    yellow  = hl_fg("DiagnosticWarn")  or "#f9e2af",
    green   = hl_fg("DiagnosticOk")    or hl_fg("String") or "#a6e3a1",
    blue    = hl_fg("Function")        or "#89b4fa",
    mauve   = hl_fg("Keyword")         or "#cba6f7",
    red     = hl_fg("DiagnosticError") or "#f38ba8",
    overlay = hl_fg("Comment")         or "#6c7086",
    peach   = hl_fg("Constant")        or "#fab387",
    surface = hl_fg("LineNr")          or "#585b70",
  }
end

function M.lualine_theme()
  return lualine_themes[M.colorscheme] or "auto"
end

-- Applies the current colorscheme and saves the choice.
function M.apply()
  if M.colorscheme == "catppuccin" then
    require("catppuccin").setup({ flavour = M.variant or "mocha" })
  elseif M.colorscheme == "tokyonight" then
    require("tokyonight").setup({ style = M.variant or "night" })
  end
  vim.cmd.colorscheme(M.colorscheme)
  save()
end

-- Switch theme at runtime: update state, apply, refresh lualine.
function M.set(colorscheme, variant)
  M.colorscheme = colorscheme
  M.variant     = variant
  M.apply()
  local ok, ll = pcall(require, "lualine")
  if ok then ll.setup(require("lunarvim.ui.statusline").lualine_opts()) end
end

-- Open a picker to choose a theme interactively.
function M.pick()
  local current = M.colorscheme .. (M.variant and ("-" .. M.variant) or "")
  local items = {}
  for _, opt in ipairs(M.options) do
    local key = opt.colorscheme .. "-" .. (opt.variant or "")
    table.insert(items, {
      opt   = opt,
      label = (key == current and "✓ " or "  ") .. opt.label,
    })
  end
  vim.ui.select(items, {
    prompt      = "Theme",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    M.set(choice.opt.colorscheme, choice.opt.variant)
  end)
end

-- Load any saved override before first apply().
load_saved()

return M
