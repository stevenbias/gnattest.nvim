# GitHub CI Configuration

This directory contains modular GitHub Actions CI configuration for gnattest.nvim, designed for reliability, performance, and maintainability.

## Structure Overview

```
.github/
├── workflows/           # Main workflow files
│   ├── ci.yml          # Main orchestration pipeline
│   ├── lint.yml        # Linting and formatting checks
│   └── test.yml        # Test suite with matrix strategy
├── config/             # Configuration files
│   └── neovim-versions.yml # Neovim version definitions
└── README.md           # This documentation
```

## Workflows

### Main CI Pipeline (`ci.yml`)
- **Purpose**: Orchestrates lint and test workflows
- **Triggers**: Push to any branch, PRs, manual dispatch
- **Jobs**: Calls lint and test workflows as reusable jobs
- **Features**: 
  - Status checking and pipeline coordination
  - Clear notifications with emoji indicators
  - Dependency management (lint → test)
  - Comprehensive error reporting

### Lint and Format (`lint.yml`)
- **Purpose**: Code quality checks and formatting validation
- **Tools**: 
  - `lunarmodules/luacheck@v1` for Lua linting
  - `JohnnyMorganz/stylua-action@v4` for formatting checks
  - `pre-commit/action@v3.0.1` for pre-commit hooks
- **Features**: 
  - Combined linting for faster execution
  - Colorized output for better readability
  - Pre-commit hook validation
  - Comprehensive code quality enforcement

### Test Suite (`test.yml`)
- **Purpose**: Run comprehensive test suite across Neovim versions
- **Matrix Strategy**: Tests on Neovim stable and nightly versions
- **Tools**: `nvim-neorocks/nvim-busted-action@v1` for testing
- **Features**: 
  - Parallel execution across versions
  - Artifact upload on test failures
  - Test log collection (.busted, luacov files)
  - 7-day artifact retention for debugging
  - Coverage tracking on stable version

## Configuration

### Neovim Versions (`config/neovim-versions.yml`)
- **Purpose**: Centralized version management
- **Current versions**: 
  - `stable` - Latest stable Neovim release
  - `nightly` - Latest nightly build
- **Usage**: Referenced by test matrix strategy

## Key Features

### Reliability
- **Proven Actions**: Uses well-maintained GitHub Actions from the community
- **Simple Architecture**: Minimal complexity, fewer points of failure
- **Standard Practices**: Follows GitHub Actions best practices
- **Version Pinning**: Specific action versions prevent breaking changes

### Performance
- **Parallel Execution**: Lint and test jobs run independently
- **Optimized Matrix**: Tests only on necessary Neovim versions
- **Fast Feedback**: Quick linting results before testing
- **Efficient Caching**: Action-level caching where appropriate

### Quality
- **Multiple Neovim Versions**: Ensures compatibility across releases
- **Comprehensive Testing**: Full test suite on each version
- **Code Quality**: Linting and formatting enforcement
- **Artifact Collection**: Easy debugging on failures
- **Coverage Tracking**: Test coverage monitoring

### Developer Experience
- **Manual Dispatch**: Can run workflows manually via GitHub UI
- **Clear Status**: Emoji-enhanced logging and status reporting
- **Artifact Handling**: Easy access to test logs on failure
- **Modular Structure**: Each workflow has single responsibility
- **Local Parity**: Same tools available locally

## Usage

### Running Workflows
- **Automatic**: On push/PR to any branch
- **Manual**: Via "workflow_dispatch" in GitHub Actions tab
- **Dependencies**: Lint must pass before tests run

### Local Development
Use the same tools locally to match CI behavior:

```bash
# Lint code (same as CI)
luacheck --codes .

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
- **Individual Logs**: Check each workflow's logs for detailed information
- **Artifacts**: Download test artifacts from failed runs for analysis
- **Status Messages**: Review pipeline coordination messages
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
ci.yml (orchestrator)
├── lint.yml (must pass first)
│   ├── luacheck
│   ├── stylua formatting check
│   └── pre-commit hooks
└── test.yml (runs after lint success)
    ├── test on stable Neovim
    └── test on nightly Neovim
└── status job (reports overall pipeline status)
```

## Performance Metrics

### Typical Execution Times
- **Lint Job**: ~30-60 seconds
- **Test Job**: ~2-5 minutes per Neovim version
- **Total Pipeline**: ~5-10 minutes

### Optimization Tips
- Run linting locally before pushing to save CI time
- Use targeted test runs during development
- Monitor artifact sizes to avoid storage limits

## Maintenance

### Adding New Neovim Versions
1. Edit `.github/config/neovim-versions.yml`
2. Update matrix strategy in `test.yml`
3. Test changes in a feature branch

### Modifying Workflows
- Each workflow is independent and can be modified separately
- Configuration changes affect all relevant workflows
- Test changes locally before committing
- Update action versions carefully

### Updating Actions
- Update action versions in respective workflow files
- Test changes thoroughly as action updates may introduce breaking changes
- Monitor action repositories for security updates
- Pin to specific versions for stability

### Regular Maintenance Tasks
- Review and update action versions monthly
- Monitor CI performance and optimize bottlenecks
- Clean up old artifacts and cache storage
- Update documentation as workflows evolve

## Troubleshooting

### Common Issues

#### Lint Failures
```bash
# Check specific linting issues
luacheck --codes .

# Fix formatting issues
stylua lua/

# Run pre-commit hooks manually
pre-commit run --all-files
```

#### Test Failures
- Download artifacts to examine test logs and coverage
- Check Neovim version compatibility
- Verify test environment setup
- Review recent code changes for breaking modifications

#### Workflow Failures
- Check GitHub Actions status page for outages
- Verify workflow syntax and permissions
- Review action version compatibility
- Check repository settings and secrets

### Getting Help
- **Workflow Logs**: Check individual workflow run logs in GitHub Actions tab
- **Artifacts**: Review artifact contents for detailed error information
- **Local Debugging**: Use local development commands to reproduce issues
- **GitHub Docs**: Refer to GitHub Actions documentation for syntax and features
- **Action Issues**: Check individual action repositories for known issues

## Best Practices

### For Contributors
1. **Run Locally**: Always run linting and tests locally before pushing
2. **Small Commits**: Keep changes focused and testable
3. **Branch Strategy**: Use feature branches for development
4. **PR Reviews**: Ensure CI passes before merging PRs

### For Maintainers
1. **Version Pinning**: Pin action versions for stability
2. **Regular Updates**: Keep actions updated for security
3. **Monitoring**: Monitor CI performance and failures
4. **Documentation**: Keep README and comments current

### Security Considerations
- Review action updates for security vulnerabilities
- Limit permissions to minimum required
- Monitor dependency changes
- Use trusted, well-maintained actions

## Integration with Development Workflow

This CI is designed to integrate seamlessly with:
- **Local Development**: Same tools available locally
- **Pre-commit Hooks**: Automated quality checks
- **Pull Requests**: Automated validation on changes
- **Release Process**: Quality gates before releases
- **Issue Tracking**: Artifacts help with bug reports