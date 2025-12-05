# Makefile
TESTS_DIR = tests/spec
MINIMAL_INIT = tests/minimal_init.lua

.PHONY: test deps

test:
	nvim --headless --noplugin -u $(MINIMAL_INIT) -c "lua require('plenary.test_harness').test_directory('$(TESTS_DIR)', { minimal_init = '$(MINIMAL_INIT)' })"

deps:
	mkdir -p vendor
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim vendor/plenary.nvim || true
	git clone --depth 1 https://github.com/MunifTanjim/nui.nvim vendor/nui.nvim || true
