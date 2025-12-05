# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
