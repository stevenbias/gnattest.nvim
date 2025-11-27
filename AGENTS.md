# AGENTS.md

## Build/Test Commands
- **Lint**: `luacheck` (runs on all .lua files)
- **Format**: `stylua lua/` (2-space indentation, 80 char width)
- **Test all**: `busted` (uses .busted config with coverage)
- **Test single**: `busted spec/<filename>_spec.lua`
- **Pre-commit**: Runs stylua, luacheck, and commitizen automatically

## Code Style Guidelines
- **Indentation**: 2 spaces (StyLua enforced)
- **Line width**: 80 characters max
- **Imports**: Use `local module = require("path")` format
- **Naming**: snake_case for variables/functions, PascalCase for modules
- **Error handling**: Use `error()` for invalid options, return nil+error for recoverable failures
- **Vim API**: Access via `vim.api.nvim_*` functions
- **Testing**: Use busted framework with `describe/it/before_each/after_each`
- **Globals**: Only `vim` is allowed as read global (luacheck config)
- **File structure**: Module code in `lua/`, tests in `spec/` with matching `_spec.lua` suffix