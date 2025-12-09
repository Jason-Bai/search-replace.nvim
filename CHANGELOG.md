# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2024-12-09

### Added

- **Visual Selection Pre-fill** - Select text in visual mode and press `<leader>sr` to auto-fill search field
  - Automatically escapes regex special characters
  - Auto-focuses replace field for quick workflow
  - Configurable via `visual` config options
- **Search Options Toggle** - Quick toggle for case sensitivity and whole word matching
  - Press `<C-i>` in Flags field to toggle case sensitivity (shows `[Aa]` or `[aa]`)
  - Press `<C-w>` in Flags field to toggle whole word matching (shows `[W]` or `[ ]`)
  - Status indicators displayed in Flags title bar
  - Integrated with ripgrep command builder

## [0.2.0] - Previous Release

- **Browse Mode (v0.2.0)** - Navigate through search matches before replacing
  - Press `o` in Results window to enter Browse Mode
  - Use `n`/`N` to jump between matches in current file
  - Press `q` to exit Browse Mode and return to Results
  - Smart focus management: automatically switches to Preview window
  - Real-time highlighting with namespace API (no conflicts with user's `/` search)
  - Shows match position in title bar: `Browse [3/8] - filename:42`

### Fixed

- Browse Mode: Added safe border buffer validation to prevent NUI errors
- Browse Mode: Fixed "Buffer is not 'modifiable'" error when switching focus after Browse Mode
  - `update_preview()` now checks if Browse Mode is active before updating
  - `exit()` now restores buffer modifiable state
  - Tab/Shift-Tab now auto-exit Browse Mode before switching focus (prevents state conflicts)

### Technical

- Added `lua/search-replace/core/browse.lua` module
- Updated Results window title to include Browse Mode hint
- Integrated Browse Mode into main plugin workflow
- Added namespace-based highlighting for browse matches

## [0.1.1] - 2024-12-05

### Fixed

- Fixed keymap not working with lazy.nvim default configuration
- Fixed Enter key closing the dialog in Results window
  - Removed `<CR>` from submit keymap in Results
  - Updated documentation to reflect correct keybindings

### Documentation

- Added detailed lazy.nvim installation examples in README
  - Option 1: `lazy = false` for immediate loading
  - Option 2: Use `keys` spec for lazy loading (recommended)
- Updated Vim help documentation with both installation methods
- Added Browse Mode design document for future v0.2.0 feature
- Added demo GIF to README showcasing main workflow

## [0.1.0] - 2024-12-05

### Added

- Initial release
- Project-wide search using ripgrep
- Live preview with context and diff view
- File grouping in results
- Selective file replacement with Space toggle
- Glob pattern filtering (`*.lua`, `src/`, `!tests/`)
- Tab/Shift-Tab navigation between fields
- Configurable keymaps and window options
- Health check (`:checkhealth search-replace`)
- Error handling for missing ripgrep, file permissions, invalid regex
- Undo support for last replacement operation (press `u`)
- Search and replace history persistence with Up/Down arrow navigation
