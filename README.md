# Lunarvim

> A terminal-first Neovim distribution built for AI-assisted development.

Lunarvim is a clean, opinionated Neovim config you clone and go. It takes the modular architecture of AstroNvim, the developer ergonomics of T3, and builds an editing environment designed around AI tools living in your terminal — not bolted on as an afterthought.

---

## Requirements

Before installing, make sure you have:

| Requirement | Version | Notes |
|---|---|---|
| [Neovim](https://neovim.io/) | 0.10+ | `nvim --version` to check |
| [Git](https://git-scm.com/) | Any | For cloning and lazy.nvim |
| A [Nerd Font](https://www.nerdfonts.com/) | Any | Icons in the UI — set it in your terminal preferences |
| A C compiler | Any | Required by nvim-treesitter (`gcc` or `clang`) |

> **Recommended font:** [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) — works great in most terminals.

---

## Installation

**1. Back up your existing Neovim config** (if you have one):

```bash
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
```

**2. Clone Lunarvim as your config:**

```bash
git clone https://github.com/adamt94/Lunarvim ~/.config/nvim
```

**3. Launch Neovim:**

```bash
nvim
```

On first launch, `lazy.nvim` bootstraps itself automatically, then installs all plugins. This takes about 30–60 seconds depending on your connection. Once complete, restart Neovim and you're ready.

---

## Verifying the install

After restarting, run these to confirm everything is working:

```
:Lazy          → opens the plugin manager dashboard
:checkhealth   → reports any missing dependencies
```

Press `<Space>` and wait — the which-key popup should appear showing all available command groups.

---

## What's included

| Plugin | Purpose |
|---|---|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager — auto-bootstrapped, no manual install |
| [catppuccin](https://github.com/catppuccin/nvim) | Colorscheme (Mocha flavour) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting and code parsing |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder for files, text, buffers |
| [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer sidebar |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Statusline |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Keymap hints — press `<Space>` and wait |
| [Comment.nvim](https://github.com/numToStr/Comment.nvim) | Comment toggling (`gcc` / `gc`) |
| [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | Persistent terminal panels |

---

## Keymaps

`<leader>` is `Space`.

### Finding things

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep (search text across project) |
| `<leader>fw` | Grep word under cursor |
| `<leader>fb` | Find open buffers |
| `<leader>fr` | Recent files |
| `<leader>fk` | Find keymaps |
| `<leader>fh` | Search help tags |

### Navigation

| Key | Action |
|---|---|
| `<leader>e` | Toggle file explorer |
| `<leader>o` | Reveal current file in explorer |
| `<C-h/j/k/l>` | Move between windows |
| `<S-h>` / `<S-l>` | Previous / next buffer |

### Terminal

| Key | Action |
|---|---|
| `<leader>tt` | Open terminal (horizontal split) |
| `<leader>tf` | Open terminal (floating) |
| `<leader>tv` | Open terminal (vertical split) |
| `<Esc><Esc>` | Exit terminal mode |
| `<C-o>` | Focus editor from terminal (works inside Claude Code / Codex input) |

### Buffers & Windows

| Key | Action |
|---|---|
| `<leader>bc` | Close current buffer |
| `<leader>bC` | Close all other buffers |
| `<leader>wv` | Vertical split |
| `<leader>ws` | Horizontal split |
| `<leader>wc` | Close window |
| `<leader>w=` | Equalize window sizes |

### Editor

| Key | Action |
|---|---|
| `jk` | Exit insert mode |
| `gcc` | Toggle line comment |
| `gc` + motion | Toggle comment over motion |
| `<A-j>` / `<A-k>` | Move line / selection up or down |
| `>` / `<` (visual) | Indent / dedent, stay in visual mode |
| `<Esc>` | Clear search highlights |
| `<leader>/` | Toggle comment (shortcut for `gcc`) |

### UI Toggles

| Key | Action |
|---|---|
| `<leader>un` | Toggle line numbers |
| `<leader>ur` | Toggle relative numbers |
| `<leader>uw` | Toggle word wrap |
| `<leader>us` | Toggle spell check |

### Quit

| Key | Action |
|---|---|
| `<leader>q` | Quit (confirms if unsaved) |
| `<leader>Q` | Quit all |
| `<C-q>` | Quit (confirms if unsaved) |

---

## AI approach

Lunarvim doesn't lock you into an AI provider. The idea is simple: use your terminal.

Open a floating or split terminal with `<leader>tf`, launch whatever AI tool you prefer — `claude`, `codex`, Gemini CLI, anything — and work alongside it. The `ai/` module in the codebase is where context management lives: it tracks your open buffers, visual selections, and (eventually) named conversation threads so they can be piped directly into terminal sessions without copy-pasting.

This keeps the editor lean and you in control of which AI you're using.

---

## Project structure

```
~/.config/nvim/
├── init.lua                      # Entry point — bootstraps lazy.nvim
└── lua/
    └── lunarvim/
        ├── init.lua              # Calls core + ai setup
        ├── core/
        │   ├── init.lua          # Wires options → plugins → keymaps
        │   └── options.lua       # All vim.opt settings
        ├── keymaps/
        │   └── init.lua          # All keymaps, organised by group
        ├── plugins/
        │   └── init.lua          # Plugin specs passed to lazy.setup()
        ├── ai/
        │   └── init.lua          # Context capture (selections, buffers, threads)
        ├── ui/                   # Coming: terminal UX helpers
        └── utils/
            └── init.lua          # Shared utilities (map helper etc.)
```

---

## Roadmap

- [x] Plugin bootstrap with lazy.nvim
- [x] Core editor options and defaults
- [x] Keymap layer with which-key groups
- [ ] LSP + Mason (language server auto-install)
- [ ] AI panel commands — send selection to terminal, capture response
- [ ] Thread / session context persistence
- [ ] Dashboard / home screen
