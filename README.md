# Lunarvim

Lunarvim is a terminal-first AI editor built as a Neovim distribution. Clone it as your Neovim config and get a clean, AI-oriented editing environment out of the box.

Inspired by T3-style developer ergonomics and AstroNvim/Neovim modularity.

## Installation

```bash
# Back up existing config if needed
mv ~/.config/nvim ~/.config/nvim.bak

# Clone as your Neovim config
git clone https://github.com/adamt94/lunarvim ~/.config/nvim
nvim  # lazy.nvim auto-installs on first launch
```

## What's included

| Plugin | Purpose |
|---|---|
| `lazy.nvim` | Plugin manager (auto-bootstrapped) |
| `catppuccin` | Colorscheme (mocha flavour) |
| `nvim-treesitter` | Syntax highlighting & parsing |
| `telescope.nvim` | Fuzzy finder |
| `neo-tree.nvim` | File explorer |
| `lualine.nvim` | Statusline |
| `which-key.nvim` | Keymap discovery |
| `toggleterm.nvim` | Persistent terminal panels (AI workflow foundation) |

## Keymaps

| Key | Action |
|---|---|
| `<leader>tt` | Open terminal (horizontal split) |
| `<leader>tf` | Open terminal (floating) |
| `<leader>tv` | Open terminal (vertical split) |

## Structure

```text
.
├── init.lua                    # Bootstraps lazy.nvim, calls lunarvim.setup()
├── lua/
│   └── lunarvim/
│       ├── init.lua            # Wires core + ai setup
│       ├── core/
│       │   ├── init.lua        # Applies options, loads plugins
│       │   └── options.lua     # Vim options and leader key
│       ├── ai/
│       │   └── init.lua        # Context capture (selection, buffers, threads)
│       ├── plugins/
│       │   └── init.lua        # All plugin specs + lazy.setup()
│       ├── ui/                 # Terminal UX helpers (coming next)
│       └── utils/              # Shared utilities (coming next)
├── docs/
├── scripts/
└── tests/
```

## AI approach

Lunarvim doesn't hard-wire an AI provider. Terminal panels (via `toggleterm`) let you run whatever AI tool you prefer — Claude, Codex CLI, Gemini, etc. The `ai/` module tracks editor context (open buffers, visual selections, thread IDs) so it can be piped into those sessions. Thread and context management will be built out incrementally.

## Roadmap
- [ ] Keymap layer (`lua/lunarvim/keymaps/`)
- [ ] LSP + Mason (language server management)
- [ ] AI panel commands (send selection to terminal, pull response back)
- [ ] Thread/session context persistence
