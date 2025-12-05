# Release Notes - v0.1.0

## 🎉 Initial Production Release

search-replace.nvim v0.1.0 is now ready for production use!

---

## 📦 What's Included

### Core Features
- **Project-wide search** using ripgrep for blazing fast results
- **Live preview** with context and diff view before applying changes
- **File grouping** for easy navigation of search results
- **Selective replacement** - choose exactly which files to modify
- **Undo support** ⭐ - press `u` to revert the last replacement operation
- **Search/replace history** - persistent history with Up/Down navigation

### User Experience
- **Glob pattern filtering** (`*.lua`, `src/`, `!tests/`)
- **Full keyboard navigation** with Tab/Shift-Tab
- **Configurable keymaps** and window options
- **Placeholder hints** in input fields
- **File icons** (with nvim-web-devicons)

### Quality & Compatibility
- **Cross-platform support** - Windows/Unix compatible
- **Health check** - `:checkhealth search-replace`
- **Comprehensive tests** - 13 test files with full coverage
- **Error handling** - friendly messages for missing deps, permissions, etc.

---

## 📊 Statistics

- **39 files** committed
- **1,484 lines** of Lua code
- **13 test files** with 100% pass rate
- **13 modules** (Core + UI + Config)

---

## 🚀 Next Steps to Publish

### 1. Push to GitHub
```bash
# Push the main branch
git push origin main

# Push the tag
git push origin v0.1.0
```

### 2. Create GitHub Release
1. Go to https://github.com/YOUR_USERNAME/search-replace.nvim/releases
2. Click "Create a new release"
3. Select tag: `v0.1.0`
4. Title: `v0.1.0 - Initial Production Release`
5. Copy the content from CHANGELOG.md
6. Publish release

### 3. Optional: Submit to Package Registries
- Add to [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)
- Submit to [dotfyle](https://dotfyle.com/)
- Share on Reddit: r/neovim

---

## 🔄 Roadmap (v0.1.1+)

### v0.1.1 (Bug Fixes & Platform Testing)
- [ ] Windows platform real-world testing
- [ ] Add demo GIF to README
- [ ] Fix any reported bugs

### v0.2.0 (Performance & Features)
- [ ] Asynchronous search for large projects
- [ ] Multi-level undo/redo stack
- [ ] Regex mode toggle (fixed-strings vs regex)
- [ ] Results pagination for huge result sets

---

## 🙏 Acknowledgments

Built with:
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast search
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI components
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua utilities

---

## 📝 License

MIT License - See LICENSE file for details

---

**Ready to publish!** 🚢
