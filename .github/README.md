# GitHub CI Configuration

This directory contains a simple GitHub Actions CI configuration.

## Structure Overview

```
.github/
├── workflows/           # CI workflow files
│   └── ci.yml          # Single unified CI pipeline
└── README.md           # This documentation
```

## Workflow

### CI Pipeline (`ci.yml`)
- **Purpose**: Single unified pipeline with linear job flow
- **Triggers**: Push to any branch, PRs
- **Jobs**: Sequential execution with dependencies
- **Linear Flow**: format-check → code-quality → test-matrix → coverage-report

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
- **Purpose**: Generate coverage report from stable Neovim tests
- **Setup**: Installs luarocks and luacov for report generation
- **Process**: Downloads stable coverage artifact, generates final report
- **Artifacts**: Uploads final `luacov.stats.out` and `luacov.report.out`
- **Dependency**: Requires test-matrix job to pass



## Usage

### Running Workflows
- **Automatic**: On push/PR to any branch
- **Dependencies**: Linear flow (format-check → code-quality → test-matrix → coverage-report)

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

```
ci.yml (single pipeline)
├── format-check (StyLua formatting check)
├── code-quality (depends on format-check)
│   └── luacheck --all-files
├── test-matrix (depends on code-quality)
│   ├── test on stable Neovim with coverage
│   ├── test on nightly Neovim with coverage
│   └── uploads coverage artifacts per version
└── coverage-report (depends on test-matrix)
    ├── downloads stable coverage artifact
    └── generates final coverage report
```
