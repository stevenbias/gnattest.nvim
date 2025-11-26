# GitHub CI Configuration

This directory contains modular GitHub Actions CI configuration for gnattest.nvim.

## Structure Overview

```
.github/
├── workflows/           # Main workflow files
│   ├── ci.yml          # Main orchestration pipeline
│   ├── lint.yml        # Linting and formatting checks
│   ├── test.yml        # Test suite with matrix strategy
│   ├── security.yml    # Security vulnerability scanning
│   └── release.yml     # Release automation
├── actions/             # Reusable composite actions
│   ├── setup-lua/      # Lua environment setup with caching
│   └── cache-restore/  # Optimized dependency caching
└── config/             # Configuration files
    └── neovim-versions.yml # Neovim version definitions
```

## Workflows

### Main CI Pipeline (`ci.yml`)
- **Purpose**: Orchestrates all other workflows
- **Triggers**: Push to main/develop, PRs, manual dispatch
- **Jobs**: Calls other workflows as reusable jobs
- **Features**: Status checking, pipeline coordination

### Lint and Format (`lint.yml`)
- **Purpose**: Code quality checks
- **Tools**: Luacheck, StyLua, pre-commit hooks
- **Caching**: Lua dependencies with optimized cache keys
- **Features**: Combined linting for faster execution

### Test Suite (`test.yml`)
- **Purpose**: Run comprehensive test suite
- **Matrix**: Tests on Neovim stable and nightly
- **Coverage**: Code coverage reporting on stable version
- **Artifacts**: Test logs on failure
- **Features**: Environment verification, optimized caching

### Security Scan (`security.yml`)
- **Purpose**: Vulnerability scanning
- **Tool**: Trivy security scanner
- **Schedule**: Weekly scans plus on-demand
- **Features**: SARIF report upload, GitHub Security tab integration

### Release (`release.yml`)
- **Purpose**: Automated release creation
- **Triggers**: Git tags with `v*` pattern
- **Features**: Changelog generation, GitHub releases

## Reusable Actions

### Setup Lua Environment (`actions/setup-lua/`)
- **Purpose**: Standardized Lua and LuaRocks setup
- **Features**: 
  - Intelligent caching based on rockspec files
  - Base dependency installation (luacheck, stylua)
  - Configurable Lua version
- **Usage**: Can be called from any workflow

### Cache and Restore (`actions/cache-restore/`)
- **Purpose**: Optimized dependency caching
- **Features**:
  - Dynamic cache key generation
  - Multiple path support
  - Cache status reporting
  - Configurable cache keys and restore patterns

## Configuration

### Neovim Versions (`config/neovim-versions.yml`)
- **Purpose**: Centralized version management
- **Features**: 
  - Easy version addition
  - Coverage version specification
  - Default version settings

## Key Improvements Over Original

### Performance
- **Intelligent Caching**: Cache keys based on file hashes and versions
- **Parallel Execution**: Jobs run independently where possible
- **Optimized Dependencies**: Install only when cache misses

### Quality
- **Multiple Neovim Versions**: Test on stable and nightly
- **Coverage Reporting**: Upload to Codecov for tracking
- **Security Scanning**: Weekly vulnerability checks
- **Better Error Handling**: Comprehensive artifact collection

### Maintainability
- **Modular Structure**: Each workflow has single responsibility
- **Reusable Actions**: Common functionality extracted
- **Configuration Files**: Centralized settings management
- **Clear Documentation**: Comprehensive README and inline comments

### Developer Experience
- **Manual Dispatch**: Can run workflows manually
- **Better Logging**: Verbose output with emojis for clarity
- **Status Badges**: Clear pipeline status indication
- **Artifact Handling**: Easy access to test logs on failure

## Usage

### Running Workflows
- **Automatic**: On push/PR to main/develop branches
- **Manual**: Via "workflow_dispatch" in GitHub Actions tab
- **Scheduled**: Security scan runs weekly

### Adding New Neovim Versions
1. Edit `.github/config/neovim-versions.yml`
2. Add new version to `versions` section
3. Update matrix strategy in workflows if needed

### Modifying Workflows
- Each workflow is independent and can be modified separately
- Reusable actions can be updated in one place
- Configuration changes affect all relevant workflows

### Debugging
- Check individual workflow logs for detailed information
- Download test artifacts from failed runs
- Review cache status messages for optimization opportunities

## Future Enhancements

- **Documentation Deployment**: Auto-generate and deploy docs
- **Plugin Publishing**: Automated rockspec publishing
- **Performance Monitoring**: CI execution time tracking
- **Integration Testing**: Add end-to-end tests with real Neovim instances