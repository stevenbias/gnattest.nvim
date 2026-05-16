# AGENTS.md

This file is for agentic coding assistants working in this repository.
Follow these guidelines to keep changes consistent, safe, and reviewable.

## Project snapshot
- **Repo**: GNATtest.nvim (Neovim plugin for Ada + GNATtest)
- **Languages**: Lua (primary), Vim help docs (`doc/gnattest.txt`)
- **Neovim**: 0.10+ required
- **Primary modules**: `lua/gnattest/*.lua`, entrypoint `lua/gnattest/init.lua`
- **Commands**: defined in `plugin/gnattest.lua` under `:Gnattest`
- **Tests**: `spec/*_spec.lua` (busted)

## Key modules
- `lua/gnattest/ada_ls.lua`: Ada LS client discovery + project context.
- `lua/gnattest/xml.lua`: parse `gnattest.xml`, map source/tests.
- `lua/gnattest/navigation.lua`: switch between source/test subprograms.
- `lua/gnattest/read_only.lua`: read-only region protection + autocmds.
- `lua/gnattest/highlight.lua`: highlight groups and extmarks.
- `lua/gnattest/health.lua`: `:checkhealth gnattest` checks.
- `lua/gnattest/utils.lua`: shared helpers, notify, filesystem utilities.

## Build / lint / test commands

Run from repo root unless noted.

### Lint / format
- **Lint**: `luacheck .`
- **Format check**: `stylua --check lua/`
- **Format fix**: `stylua lua/`

### Tests
- **All tests (public API)**: `busted`
- **All tests (includes private tests)**: `GNATTEST_TEST_MODE=1 busted`
- **Single test file**: `busted spec/<name>_spec.lua`
- **Single test file + test mode**: `GNATTEST_TEST_MODE=1 busted spec/<name>_spec.lua`
- **Verbose**: `busted -v`

### Coverage
- **Generate**: `busted --coverage`
- **View report**: `cat luacov.report.out`
- **Minimum**: 90% (CI enforces on stable coverage report)

### Local install / packaging
- **Local install**: `luarocks make gnattest-scm-1.rockspec`

### Pre-commit hooks
- **Install**: `pre-commit install`
- **Run all**: `pre-commit run --all-files`

## CI behavior (from GitHub workflows)
- **Format check**: StyLua `--check` on `lua/`
- **Lint**: luacheck
- **Tests**: `busted` via nvim-busted-action with `GNATTEST_TEST_MODE=1`
- **Coverage**: threshold 90% (stable matrix result)

## Code style guidelines

### Formatting
- **Indentation**: 2 spaces (Lua); avoid tabs
- **Line width**: 80 columns (`.stylua.toml`)
- **Quotes**: prefer double quotes (StyLua)
- **Line endings**: Unix (`.stylua.toml`, `.editorconfig`)

### Imports / module layout
- Prefer `local M = {}` module pattern and `return M` at EOF.
- Use local functions for private helpers; expose only via `M`.
- Avoid cyclic requires; factor helpers into `lua/gnattest/utils.lua`.
- Keep side effects limited to module scope and autocmd setup.
- Add private exports only in test mode (see Testing conventions).

### Naming conventions
- **Functions/vars**: `snake_case`
- **Modules**: `PascalCase` only for user-facing labels; filenames are `snake_case`.
- **Constants**: `UPPER_SNAKE_CASE`
- **Plugin name**: use `GNATtest` (note casing) in UI strings.

### Types / data
- Use Lua tables for structured data; keep shapes consistent across modules.
- Prefer `vim.tbl_*`, `vim.islist()`, and `vim.iter` for table ops.
- Validate user config inputs; reject unknown options (see `lua/gnattest/config.lua`).
- Use Lua annotations (`---@class`, `---@param`, `---@return`) for public API.

### Error handling / notifications
- **Programming errors**: `error(...)` for invariants or programmer misuse.
- **Recoverable failures**: return `nil, err` or `false, err` and let caller decide.
- Use `pcall(...)` around Treesitter and risky Neovim APIs.
- User-facing issues go through `vim.notify` or `utils.notify` with log levels.
- Keep log level semantics consistent with existing messages.

### Neovim API usage
- Prefer `vim.api.nvim_*` over `vim.fn.*` when possible.
- Prefer `vim.fs.*` for file operations.
- Use `vim.system` for async shell commands; avoid blocking the UI.
- Guard Treesitter access with `pcall` and handle missing parser gracefully.

### Configuration behavior
- Defaults live in `lua/gnattest/config.lua` and are merged with user opts.
- Use `vim.tbl_deep_extend("force", ...)` for merges to preserve defaults.
- Preserve existing option names and validation errors unless changing API.

### GNATtest workflow / UX
- Commands are subcommands of `:Gnattest` (generate/build/run/run_all/run_cursor/clean/switch).
- If adding new commands, follow the pattern in `plugin/gnattest.lua`.
- Preserve existing user-facing wording and quickfix behavior.
- Only GNAT project files (`.gpr`) are supported.
- Read-only protection should never silently modify user code.

### Testing conventions
- File layout: `spec/<module>_spec.lua` mirrors `lua/gnattest/<module>.lua`.
- Use `spec/helpers/common.lua` to mock vim and helpers.
- Cleanup in `after_each`: `package.loaded`, `package.preload`, `_G.vim`.
- Prefer `luassert.stub` for API mocks and restore after tests.
- **Dual-mode tests**:
  - Normal: public API only
  - `GNATTEST_TEST_MODE=1`: include private function tests
- Private functions can be exposed at EOF:
  ```lua
  if os.getenv("GNATTEST_TEST_MODE") then
    M._private_fn = private_fn
  end
  ```

### Docs / help files
- Help docs are in `doc/gnattest.txt` and use Vim help formatting.
- API docs are inserted between CI markers; keep markers intact.
- Update README examples when you add or change user commands.

## Linting rules (luacheck)
- Global `vim` is allowed.
- No other implicit globals (see `.luacheckrc`).

## Release / automation notes
- CI runs on push and PR; coverage enforced on stable matrix job.
- Pre-release automation runs on `dev` and creates a PR to `main`.

## Commit rules (for agents)
Only create a git commit if the user explicitly requests it.
When authorized, follow the repo's conventional commit types:
`feat`, `fix`, `docs`, `refactor`, `test`, `style`, `chore`, `ci`, `build`, `perf`.

## Cursor / Copilot rules
- No Cursor rules found in `.cursor/rules/` or `.cursorrules`.
- No Copilot rules found in `.github/copilot-instructions.md`.
