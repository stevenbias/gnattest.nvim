# AGENTS.md

## Build/Test Commands
- **Lint**: `luacheck .` (runs on all .lua files, configured in .luacheckrc)
- **Format check**: `stylua --check lua/` (2-space indentation, 80 char width, auto-prefer double quotes)
- **Format fix**: `stylua lua/` (fixes formatting issues automatically)
- **Test all**: `busted` or `busted -v` (uses .busted config with coverage enabled)
- **Test all with test mode**: `GNATTEST_TEST_MODE=1 busted` (runs all tests including unit tests that require internal exports)
- **Test single file**: `busted spec/<filename>_spec.lua` (e.g., `busted spec/utils_spec.lua`)
- **Test with coverage**: `busted --coverage` (generates luacov reports)
- **Coverage threshold**: Minimum 90% coverage required (enforced in CI)
- **Pre-commit hooks**: Install with `pre-commit install`, runs stylua, luacheck, and commitizen
- **Run all pre-commit**: `pre-commit run --all-files` (manual check before commit)
- **Local install**: `luarocks make gnattest-scm-1.rockspec` (installs plugin locally)
- **View coverage**: Open `luacov.report.out` after running tests with coverage

## Code Style Guidelines

### Formatting & Structure
- **Indentation**: 2 spaces (StyLua enforced, overrides .editorconfig)
- **Line width**: 80 characters max (StyLua enforced)
- **Quote style**: Auto-prefer double quotes (StyLua configured)
- **File endings**: Unix style (LF)

### Module & Import Patterns
- **Module structure**: Use module table pattern `local M = {}` and `return M`
- **Imports**: Use `local module = require("path")` format at file top
- **Relative imports**: Use dot notation for relative requires within the project
- **Plugin structure**: Main entry in `lua/gnattest/init.lua`, submodules in `lua/gnattest/`

### Naming Conventions
- **Variables/Functions**: snake_case (e.g., `get_bufpath`, `is_gnattest_file`)
- **Modules**: PascalCase for module names (e.g., `gnattest.Utils`)
- **Constants**: UPPER_SNAKE_CASE for configuration constants
- **Private functions**: Use `local` prefix for internal functions
- **Command names**: PascalCase with plugin prefix (e.g., `GNATtest`)

### Error Handling
- **Invalid options**: Use `error("message")` for programming errors
- **Recoverable failures**: Return `nil, error_message` pattern
- **API calls**: Use `pcall` for operations that might fail (e.g., `pcall(require, plugin_name)`)
- **User notifications**: Use `vim.notify()` or custom `M.notify()` with log levels

### Vim API Usage
- **API functions**: Access via `vim.api.nvim_*` functions
- **Commands**: Create with `vim.api.nvim_create_user_command()`
- **Autocmds**: Use `vim.api.nvim_create_autocmd()` with proper patterns
- **Treesitter**: Use `vim.treesitter.*` API with error handling for missing parsers
- **File operations**: Prefer `vim.fs.*` functions over `vim.fn.*`

### Testing Guidelines
- **Framework**: Use busted with `describe/it/before_each/after_each`
- **Test structure**: Mirror source structure in `spec/` with `_spec.lua` suffix
- **Mocking**: Use `luassert.stub` for mocking vim API functions
- **Globals**: Mock `_G.vim` in tests with required API functions
- **Package loading**: Use `package.preload` for module stubbing
- **Assertions**: Use `assert.*` functions from luassert
- **Data-driven tests**: Use tables to consolidate similar test cases
- **Test consolidation**: Merge duplicate/similar tests when behavior is identical
- **Variable usage**: Inline single-use variables instead of creating intermediates
- **Nil in arrays**: Wrap nil values in tables when using `ipairs()` (e.g., `{{val=nil}}`)
- **Comments**: Keep section headers and technical prerequisites; remove obvious descriptions

### Lua Best Practices
- **Globals**: Only `vim` allowed as read global (luacheck enforced)
- **Table operations**: Use `vim.tbl_*` utilities for table manipulation
- **Iteration**: Use `vim.iter` for functional-style iteration when available
- **String patterns**: Use Lua string patterns, avoid regex unless necessary
- **Type checking**: Use `vim.islist()` for list type checking

### Project-Specific Patterns
- **Ada integration**: Handle Ada language server and GNATtest tool integration
- **File patterns**: Use `**/gnattest/` patterns for test file detection
- **XML parsing**: Handle GNATtest XML output for test information
- **Navigation**: Implement source/test file switching for Ada subprograms
- **Read-only regions**: Support for protected code regions in test files

### Configuration Files
- **StyLua**: Configured in `.stylua.toml` (2 spaces, 80 width, double quotes)
- **Luacheck**: Configured in `.luacheckrc` (allows `vim` global, no comment length limit)
- **Busted**: Configured in `.busted` (coverage enabled, nlua runtime, verbose output)
- **Pre-commit**: Hooks for stylua, luacheck, and commitizen
- **Commitizen**: Uses conventional commit format with cz_conventional_commits, semver2 scheme
- **EditorConfig**: Configured in `.editorconfig` (though StyLua overrides some settings)

### Environment & Testing Patterns
- **Test mode**: Use `GNATTEST_TEST_MODE` environment variable for test-specific exports
- **Mocking pattern**: Use `package.preload` for stubbing modules in tests
- **Vim API mocking**: Mock `_G.vim` with required API functions using helper utilities
- **Cleanup**: Always clean up `_G.vim` and `package.preload` in `after_each`
- **Test helpers**: Use `spec.helpers.common` for creating vim API mocks

### Development Workflow
- **Branch strategy**: Work on feature branches, merge to main via PR
- **Quality gates**: All tests must pass, linting must be clean
- **Documentation**: Update README.md for user-facing changes
- **Versioning**: Use semantic versioning via rockspec
- **Dependencies**: Minimal external dependencies (lua >= 5.1, busted for testing)

### Additional Patterns
- **Test exports**: Use conditional exports with `os.getenv("GNATTEST_TEST_MODE")` for test utilities
- **Parser handling**: Always wrap `vim.treesitter` calls in `pcall` with user-friendly error messages
- **File detection**: Use string patterns and `vim.fs.find` for locating project files
- **Conditional features**: Check for optional plugins with `pcall(require, plugin_name)` before usage
- **String manipulation**: Use `gsub` for trimming whitespace, prefer Lua string patterns over regex
- **Table insertion**: Use `table.insert` for dynamic array building in configuration patterns

### Environment & Testing Patterns
- **Test mode**: Use `GNATTEST_TEST_MODE` environment variable for test-specific exports
- **Mocking pattern**: Use `package.preload` for stubbing modules in tests
- **Vim API mocking**: Mock `_G.vim` with required API functions using helper utilities
- **Cleanup**: Always clean up `_G.vim` and `package.preload` in `after_each`
- **Test helpers**: Use `spec.helpers.common` for creating vim API mocks

### Development Workflow
- **Branch strategy**: Work on feature branches, merge to main via PR
- **Quality gates**: All tests must pass, linting must be clean
- **Documentation**: Update README.md for user-facing changes
- **Versioning**: Use semantic versioning via rockspec
- **Dependencies**: Minimal external dependencies (lua >= 5.1, busted for testing)

### Code Examples

#### Module Structure
```lua
local M = {}

function M.public_function()
  -- Use snake_case for functions
end

local function private_function()
  -- Use local for private functions
end

-- Test exports at end of file
if os.getenv("GNATTEST_TEST_MODE") then
  M._private_function = private_function
end

return M
```

#### Error Handling Pattern
```lua
-- For operations that might fail
local ok, result = pcall(vim.treesitter.get_parser, buf, "ada")
if not ok or not result then
  vim.notify("User-friendly message", vim.log.levels.WARN)
  return nil
end

-- For invalid configuration
if opts ~= nil and next(opts) ~= nil then
  error("Options are not supported")
end
```

#### Test Structure Example
```lua
describe("module_name", function()
  before_each(function()
    _G.vim = helpers.create_basic_vim_api()
    package.preload["module"] = function() return mock end
  end)

  after_each(function()
    package.loaded["module"] = nil
    package.preload["module"] = nil
  end)

  it("describes the behavior", function()
    assert.equals(expected, actual)
  end)
end)
```

#### Test Optimization Pattern
```lua
-- Before: Duplicate tests
it("handles case A", function()
  local result = func("input_a")
  assert.equals("expected_a", result)
end)
it("handles case B", function()
  local result = func("input_b")
  assert.equals("expected_b", result)
end)

-- After: Data-driven test
it("handles multiple inputs", function()
  local cases = {
    { input = "input_a", expected = "expected_a" },
    { input = "input_b", expected = "expected_b" },
  }
  for _, case in ipairs(cases) do
    assert.equals(case.expected, func(case.input))
  end
end)

-- Testing nil values with ipairs()
it("handles nil values", function()
  local cases = {
    { val = "text" },
    { val = nil },     -- Wrapped to avoid array hole
    { val = "" },
  }
  for _, case in ipairs(cases) do
    local result = func(case.val)
    assert.is_not_nil(result)
  end
end)
```

#### Vim API Patterns
```lua
-- Autocmd creation
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group_id,
  pattern = { "*.ads", "*.adb" },
  callback = function()
    -- handler code
  end,
})

-- Namespace and highlighting
local ns = vim.api.nvim_create_namespace("plugin_name")
vim.api.nvim_set_hl(ns, "HighlightGroup", { bg = "#color" })

-- Extmarks for virtual text
vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
  end_row = end_row,
  hl_group = "HighlightGroup",
  virt_text = { { "icon", "HighlightGroup" } },
})
```

### Common Pitfalls to Avoid
- **Don't**: Use `cd` in bash commands; use `workdir` parameter instead
- **Don't**: Mix tabs and spaces; StyLua enforces 2-space indentation
- **Don't**: Forget to clean up mocks in `after_each` blocks
- **Don't**: Access vim API without mocking in tests
- **Don't**: Use `vim.fn.*` when `vim.fs.*` or `vim.api.*` alternatives exist
- **Don't**: Hardcode paths; use `vim.fs.find` for file discovery
- **Don't**: Skip the test mode check for private function exports
- **Don't**: Create duplicate test cases; use data-driven testing with tables
- **Don't**: Use `ipairs()` on arrays with nil values without wrapping (causes early loop exit)
- **Don't**: Add comments that restate obvious code; keep only section headers and technical notes