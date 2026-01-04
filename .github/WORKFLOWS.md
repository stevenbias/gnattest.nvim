# GitHub CI Configuration

> 📖 **For plugin usage documentation**, see the [main README](../README.md)

This directory contains the CI/CD configuration for the GNATtest.nvim plugin.

## Structure Overview

```
.github/
├── workflows/           # CI/CD workflow files
│   ├── ci.yml          # Code quality pipeline
│   └── release.yml     # Release automation pipeline
└── WORKFLOWS.md        # This documentation
```

## Workflows

### CI Pipeline (`ci.yml`)
- **Purpose**: Code quality assurance
- **Triggers**: Push to any branch, Pull Requests
- **Jobs**: Sequential execution with dependencies
- **Linear Flow**: format-check → code-quality → test-matrix → coverage-report

### Release Pipeline (`release.yml`)
- **Purpose**: Release automation tasks
- **Triggers**: GitHub Release published
- **Jobs**: generate-api-docs
- **Flow**: Generates and commits API documentation to main branch

#### Job Details

**Format-Check Job**
- **Purpose**: Code formatting validation
- **Tool**: `JohnnyMorganz/stylua-action@v4`
- **Check**: Validates 2-space indentation and 80-char width

**Code-Quality Job** 
- **Purpose**: Code quality checks
- **Tool**: `lunarmodules/luacheck@v1` for Lua linting
- **Args**: `--all-files` to check all Lua files in the repository
- **Dependency**: Requires format-check job to pass

**Test-Matrix Job**
- **Purpose**: Run test suite across Neovim versions with coverage
- **Matrix Strategy**: Tests on stable and nightly Neovim
- **Tool**: `nvim-neorocks/nvim-busted-action@v1` with `--coverage` flag
- **Artifacts**: Uploads coverage data per Neovim version (`coverage-stable`, `coverage-nightly`)
- **Dependency**: Requires code-quality job to pass

**Coverage-Report Job**
- **Purpose**: Generate coverage report from stable Neovim tests and check threshold
- **Setup**: Installs luarocks and luacov for report generation
- **Process**: Downloads stable coverage artifact, generates final report
- **Threshold**: Requires minimum 90% code coverage to pass
- **Artifacts**: Uploads final `luacov.stats.out` and `luacov.report.out`
- **Dependency**: Requires test-matrix job to pass

#### Release Pipeline Job Details

**Generate-API-Docs Job**
- **Purpose**: Auto-generate API documentation from luaCATS annotations
- **Trigger**: Only runs when a GitHub Release is published
- **Tool**: `vimcats` CLI tool (Rust-based)
- **Process**:
  1. Checks out the released tag
  2. Installs Rust toolchain and vimcats
  3. Generates API docs from Lua files with luaCATS annotations
  4. Integrates generated docs into `doc/gnattest.txt`
  5. Commits updated docs to main branch with `[skip ci]` tag
- **Commit Target**: main branch
- **Skip CI**: Prevents infinite workflow loops



## Usage

### Running CI Workflow
- **Automatic**: On push/PR to any branch
- **Dependencies**: Linear flow (format-check → code-quality → test-matrix → coverage-report)

### Running Release Workflow
- **Automatic**: When a GitHub Release is published
- **Manual**: Create a release via GitHub UI or `gh` CLI
- **Example**:
  ```bash
  gh release create v0.2.0 --title "Release v0.2.0" --notes "Release notes"
  ```

### Local Development
Use the same tools locally to match CI behavior:

```bash
# Lint code (same as CI)
luacheck .

# Check formatting (same as CI)
stylua --check lua/

# Fix formatting locally
stylua lua/

# Run all tests (same as CI)
busted -v

# Run single test file
busted spec/<filename>_spec.lua

# Run tests with coverage
busted --coverage
```

### Pre-commit Hooks
The repository includes pre-commit hooks that run automatically:
```bash
# Install pre-commit hooks (one-time setup)
pre-commit install

# Run hooks manually on all files
pre-commit run --all-files
```

### Debugging
- **Individual Logs**: Check each job's logs for detailed information
- **Artifacts**: Download coverage reports from successful runs (default retention)
- **Local Reproduction**: Use same commands locally to reproduce issues

## Configuration Files

The CI uses these configuration files in the repository root:

- **`.busted`** - Test framework configuration with coverage settings
- **`.luacheckrc`** - Linting rules and global variable allowances  
- **`.stylua.toml`** - Code formatting preferences (2-space indentation, 80-char width)
- **`.pre-commit-config.yaml`** - Pre-commit hook definitions
- **`AGENTS.md`** - Development guidelines and commands for AI agents

## Workflow Dependencies

### CI Pipeline
```
ci.yml (code quality)
├── format-check (StyLua formatting check)
├── code-quality (depends on format-check)
│   └── luacheck --all-files
├── test-matrix (depends on code-quality)
│   ├── test on stable Neovim with coverage
│   ├── test on nightly Neovim with coverage
│   └── uploads coverage artifacts per version
└── coverage-report (depends on test-matrix)
    ├── downloads stable coverage artifact
    ├── generates final coverage report
    └── validates 90% minimum coverage threshold
```

### Release Pipeline
```
release.yml (release automation)
└── generate-api-docs (triggered on release published)
    ├── checkout released tag
    ├── install Rust + vimcats
    ├── generate API docs from luaCATS annotations
    ├── integrate into doc/gnattest.txt
    └── commit to main branch [skip ci]
```
