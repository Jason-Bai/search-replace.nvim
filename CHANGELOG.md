# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
