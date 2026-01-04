# Contributing to GNATtest.nvim

Thank you for considering contributing to this project!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/StevenBias/gnattest.nvim.git
   cd gnattest.nvim
   ```

2. Install dependencies:
   ```bash
   # Install luarocks if not already installed
   # Then install test dependencies
   luarocks install busted
   luarocks install nlua
   luarocks install luacheck
   luarocks install luacov
   ```

3. Install pre-commit hooks:
   ```bash
   pre-commit install
   ```

## Code Style

This project follows strict code quality standards. See [AGENTS.md](AGENTS.md) for comprehensive guidelines.

**Quick checklist:**
- ✅ Use 2-space indentation
- ✅ Keep lines under 80 characters
- ✅ Run `stylua lua/` before committing
- ✅ Run `luacheck .` - must pass with no errors
- ✅ Follow snake_case for functions/variables
- ✅ Use conventional commit messages

## Testing Requirements

**All tests must pass:**
```bash
# Standard tests (public API)
busted

# Extended tests (includes private functions)
GNATTEST_TEST_MODE=1 busted
```

**Code coverage:**
- Minimum 90% required (currently at 99.82%)
- Run `busted --coverage` to check coverage
- View report: `cat luacov.report.out`

**Testing guidelines:**
- Mirror module structure: `spec/<module>_spec.lua` tests `lua/gnattest/<module>.lua`
- Use test helpers from `spec/helpers/common.lua`
- Clean up mocks in `after_each` blocks
- See [AGENTS.md](AGENTS.md) for detailed testing patterns

## Pull Request Process

1. Fork the repository

2. Create a feature branch:
   - `feat/your-feature-name` for new features
   - `fix/your-bug-fix` for bug fixes
   - `docs/your-doc-improvement` for documentation

3. Make your changes:
   - Write/update tests
   - Update documentation if needed
   - Ensure code follows style guidelines

4. Run quality checks:
   ```bash
   # Format code
   stylua lua/
   
   # Lint
   luacheck .
   
   # Test
   busted
   GNATTEST_TEST_MODE=1 busted
   
   # Pre-commit checks
   pre-commit run --all-files
   ```

5. Commit using conventional commits:
   - `feat: Add new feature`
   - `fix: Fix bug`
   - `docs: Update documentation`
   - `style: Format code`
   - `refactor: Refactor code`
   - `test: Add tests`
   - `chore: Maintenance`

6. Push and create a Pull Request with:
   - Clear description of changes
   - Why the change is needed
   - Any related issues

## Development Tips

**Running single test file:**
```bash
busted spec/utils_spec.lua
```

**Debugging tests:**
```bash
busted -v  # Verbose output
```

**Local plugin testing:**
```bash
luarocks make gnattest-scm-1.rockspec
```

## Questions or Ideas?

- Open an issue for discussion before starting major work
- Ask questions in issues - no question is too small
- Suggest improvements - all feedback is valuable

## Code of Conduct

- Be respectful and constructive
- Welcome newcomers and different perspectives
- Focus on what's best for the project and community

Thank you for contributing! 🎉
