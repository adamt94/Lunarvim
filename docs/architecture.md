# Architecture Foundation

## Core idea
Lunarvim is being bootstrapped as a terminal-first AI editor inspired by T3-style developer experience and Neovim/AstroNvim modularity.

## Initial folder layout
- `init.lua`: Neovim entrypoint.
- `lua/lunarvim/`: main application namespace.
  - `core/`: baseline editor behavior and defaults.
  - `ai/`: AI provider abstraction and workflows.
  - `plugins/`: plugin declarations and integration points.
  - `ui/`: terminal UX and visual helpers.
  - `utils/`: shared utility modules.
- `docs/`: architecture and planning notes.
- `tests/`: test files for Lua modules and integration checks.
- `scripts/`: project automation and developer tooling scripts.
