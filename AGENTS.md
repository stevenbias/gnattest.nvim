# AGENTS.md

## Build/Test Commands
- **Lint**: `luacheck .` (configured in .luacheckrc)
- **Format check**: `stylua --check lua/` (2-space indent, 80 char width, double quotes)
- **Format fix**: `stylua lua/` (auto-fixes formatting)
- **Test all**: `busted` or `busted -v` (tests public API only - must pass)
- **Test all with test mode**: `GNATTEST_TEST_MODE=1 busted` (adds private function unit tests - must also pass)
- **Test single file**: `busted spec/<filename>_spec.lua` (e.g., `busted spec/utils_spec.lua`)
- **Test single file with test mode**: `GNATTEST_TEST_MODE=1 busted spec/utils_spec.lua`
- **Important**: Tests must pass BOTH with and without GNATTEST_TEST_MODE. CI runs with mode enabled.
- **Coverage report**: `busted --coverage && cat luacov.report.out` (minimum 90% required)
- **Pre-commit hooks**: `pre-commit install` (runs stylua, luacheck, commitizen)
- **Run pre-commit**: `pre-commit run --all-files` (manual check)
- **Local install**: `luarocks make gnattest-scm-1.rockspec`

## Code Style Guidelines

### Formatting & Structure
- **Indentation**: 2 spaces (StyLua enforced via .stylua.toml)
- **Line width**: 80 characters max
- **Quotes**: Auto-prefer double quotes
- **File endings**: Unix (LF)
- **Module pattern**: `local M = {}` ... `return M`

### Naming Conventions
- **Functions/Variables**: snake_case (`get_bufpath`, `is_gnattest_file`)
- **Modules**: PascalCase (`gnattest.Utils`)
- **Constants**: UPPER_SNAKE_CASE
- **Private functions**: `local function name()` (no underscore prefix needed)
- **Commands**: PascalCase with plugin prefix (`GNATtest`)

### Module & Import Patterns
- Place `require()` statements at file top: `local module = require("path")`
- Use dot notation for relative imports within project
- Main entry point: `lua/gnattest/init.lua`
- Submodules: `lua/gnattest/<module>.lua`

### Error Handling
- **Programming errors**: `error("message")` (e.g., invalid configuration)
- **Recoverable failures**: Return `nil, error_message` pattern
- **Risky operations**: Wrap in `pcall()` (e.g., `pcall(require, plugin_name)`)
- **User notifications**: `vim.notify(msg, vim.log.levels.WARN)` or `M.notify()`

### Vim API Patterns
- Use `vim.api.nvim_*` for API calls
- Create commands: `vim.api.nvim_create_user_command()`
- Create autocmds: `vim.api.nvim_create_autocmd()`
- Treesitter: Always wrap in `pcall()` with user-friendly error messages
- File operations: Prefer `vim.fs.*` over `vim.fn.*`
- Namespaces: `vim.api.nvim_create_namespace("plugin_name")`
- Extmarks: `vim.api.nvim_buf_set_extmark()` for virtual text/highlights

### Testing Patterns
- **Framework**: Busted with `describe/it/before_each/after_each`
- **File naming**: `spec/<module>_spec.lua` mirrors `lua/gnattest/<module>.lua`
- **Mock vim API**: Use `spec.helpers.common.create_basic_vim_api()`
- **Mock modules**: Use `package.preload["module"] = function() return mock end`
- **Cleanup**: Always clear `package.loaded`, `package.preload`, and `_G.vim` in `after_each`
- **Assertions**: Use `assert.equals()`, `assert.is_true()`, etc. from luassert
- **Data-driven tests**: Use tables to consolidate similar cases
- **Nil in arrays**: Wrap in table: `{ {val=nil}, {val=""} }` (avoid array holes with ipairs)
- **Comments**: Keep section headers; remove obvious descriptions
- **Test mode & exports**: 
  - Without GNATTEST_TEST_MODE: Tests run against public API only (must pass)
  - With GNATTEST_TEST_MODE=1: Enables additional unit tests for private functions (CI uses this)
  - Both modes must pass - test mode only adds coverage, cannot break public API
  - Export private functions conditionally at module end:
    ```lua
    if os.getenv("GNATTEST_TEST_MODE") then
      M._private_function = private_function
    end
    ```
  - Wrap private function test suites in `if os.getenv("GNATTEST_TEST_MODE")` blocks

### Lua Best Practices
- **Globals**: Only `vim` allowed as read global (enforced by luacheck)
- **Table operations**: Use `vim.tbl_*` utilities
- **Iteration**: Use `vim.iter` for functional-style iteration
- **String patterns**: Prefer Lua patterns over regex
- **Type checking**: Use `vim.islist()` for list validation

### Project-Specific Patterns
- **Ada integration**: Handle Ada language server and GNATtest tool
- **File detection**: Use `**/gnattest/` patterns for test file detection
- **XML parsing**: Parse GNATtest XML output for test information
- **Navigation**: Implement source ↔ test file switching for Ada subprograms
- **Read-only regions**: Protect code regions in test files from editing
- **File discovery**: Use `vim.fs.find()` with patterns, not hardcoded paths

### Development Workflow
- **Branch strategy**: Feature branches → PR → main
- **Quality gates**: All tests pass, linting clean, 90% coverage minimum
- **Documentation**: Update README.md for user-facing changes
- **Versioning**: Semantic versioning via rockspec
- **Dependencies**: Minimal (lua >= 5.1, busted/nlua for testing only)
- **Commits**: Use conventional commit format (enforced by commitizen)
- **AI commits**: Every commit made by AI must end with "Generated by AI" in the commit body


## Code Examples

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

## Common Pitfalls to Avoid
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