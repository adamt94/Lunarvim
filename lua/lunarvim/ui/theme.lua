-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │  Theme config — this is the only file you need to edit to change theme.  │
-- └──────────────────────────────────────────────────────────────────────────┘

local M = {}

-- ── User settings ─────────────────────────────────────────────────────────────

M.colorscheme = "catppuccin"
M.variant     = "mocha"   -- catppuccin: "latte" | "frappe" | "macchiato" | "mocha"
                           -- tokyonight: "night" | "storm" | "moon" | "day"

-- ── Per-theme palettes ────────────────────────────────────────────────────────
-- Add an entry here when you add a new colorscheme plugin.
-- Keys must match the colorscheme string (or "name-variant" for catppuccin).
-- All other themes fall back to deriving colors from highlight groups.

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

-- Lualine theme names for colorschemes that ship their own.
-- Falls back to "auto" (lualine derives from your active colorscheme).
local lualine_themes = {
  catppuccin = "catppuccin",
  tokyonight = "tokyonight",
  gruvbox    = "gruvbox",
  kanagawa   = "kanagawa",
  nightfox   = "nightfox",
}

-- ── Runtime helpers ───────────────────────────────────────────────────────────

local function hl_fg(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and hl.fg then return string.format("#%06x", hl.fg) end
end

-- Returns the active semantic color palette.
-- Uses a hardcoded palette when available, otherwise derives from highlights
-- so any colorscheme works without manual configuration.
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

-- Returns the lualine theme string.
function M.lualine_theme()
  return lualine_themes[M.colorscheme] or "auto"
end

-- Configures the colorscheme plugin and applies it.
-- Called once from plugins/init.lua after lazy has loaded.
function M.apply()
  if M.colorscheme == "catppuccin" then
    require("catppuccin").setup({ flavour = M.variant or "mocha" })
  elseif M.colorscheme == "tokyonight" then
    require("tokyonight").setup({ style = M.variant or "night" })
  end
  vim.cmd.colorscheme(M.colorscheme)
end

return M
