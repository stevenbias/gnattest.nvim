# GitHub CI Configuration

> 📖 **For plugin usage documentation**, see the [main README](../README.md)

This directory contains the CI/CD configuration for the GNATtest.nvim plugin.

## Structure Overview

```
.github/
├── workflows/           # CI/CD workflow files
│   ├── ci.yml                    # Code quality pipeline
│   ├── process-prerelease.yml    # Pre-release automation
│   └── publish-production.yml    # Production release automation
└── WORKFLOWS.md        # This documentation
```

## Workflows

### CI Pipeline (`ci.yml`)
- **Purpose**: Code quality assurance
- **Triggers**: Push to any branch, Pull Requests
- **Jobs**: Sequential execution with dependencies
- **Linear Flow**: format-check → code-quality → test-matrix → coverage-report

### Release Automation Workflows

The release automation uses a two-workflow system for pre-release → production cycle:

#### Process Pre-Release Workflow (`process-prerelease.yml`)
- **Purpose**: Create PR for production release
- **Triggers**: GitHub pre-release published (tag ending with `-pre`)
- **Requirements**:
  - Pre-release must be created from `dev` branch
  - Tag must follow pattern `v{version}-pre` (e.g., `v0.1.0-pre`)
- **Process**:
  1. Validates pre-release conditions
  2. Checks out dev branch
  3. Extracts production version
  4. Injects changelog section into PR body
  5. Creates PR: dev → main
  6. Auto-assigns repository owner as reviewer
- **PR Labels**: `automated`, `release`

#### Publish Production Workflow (`publish-production.yml`)
- **Purpose**: Create production tag and draft release after PR merge
- **Triggers**: PR closed on main branch with `release` label
- **Requirements**: PR must be merged (not just closed)
- **Process**:
  1. Extracts version from PR title
  2. Creates production tag `v{version}` on main
  3. Creates draft production release
  4. Copies release notes from pre-release
  5. Comments on PR with draft release link
- **Manual Step**: User publishes draft release when ready

#### Tag Naming Convention
- **Pre-release**: `v{version}-pre` (e.g., `v0.1.0-pre`)
- **Production**: `v{version}` (e.g., `v0.1.0`)
- **Pattern**: Production strips `-pre` suffix from pre-release tag

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

#### Release Automation Pipeline Job Details

**Process-Prerelease Job**
- **Purpose**: Create PR for production release
- **Trigger**: Only runs when a pre-release with `-pre` suffix is published
- **Process**:
  1. Validates pre-release tag ends with `-pre`
  2. Checks out dev branch
  3. Validates tag commit is on dev
  4. Extracts production version (strips `-pre` suffix)
  5. Injects changelog section into PR body
  6. Creates PR from dev to main with labels and reviewer

**Publish-Production Job**
- **Purpose**: Create production tag and draft release after PR merge
- **Trigger**: Only runs when PR with `release` label is merged to main
- **Process**:
  1. Extracts version from PR title
  2. Validates version format (`v0.1.0`)
  3. Finds corresponding pre-release (`v0.1.0-pre`)
  4. Copies release notes from pre-release
  5. Creates production tag on main branch
  6. Creates draft production release
  7. Comments on PR with release link
- **Release Type**: Draft (user manually publishes)
- **Fallback**: Uses generic notes if pre-release not found



## Usage

### Running CI Workflow
- **Automatic**: On push/PR to any branch
- **Dependencies**: Linear flow (format-check → code-quality → test-matrix → coverage-report)

### Running Release Workflows

#### Creating a Pre-Release (Manual Step)
1. Ensure you're on the `dev` branch with latest changes
2. Bump version and update changelog with Commitizen:
   ```bash
   cz bump --release-as 0.1.0-pre
   git push origin dev --tags
   ```
3. Create and publish a pre-release with `-pre` suffix:
   ```bash
   gh release create v0.1.0-pre \
     --target dev \
     --prerelease \
     --title "Pre-release v0.1.0-pre" \
     --notes "Pre-release for testing v0.1.0"
   ```

#### Automated Process (No Manual Intervention)
- **Process Pre-Release Workflow** automatically:
  1. Validates tag format and branch
  2. Creates PR to main branch with changelog section
  3. Assigns you as reviewer

#### Review and Merge PR (Manual Step)
1. Review the automated PR
2. Review changelog section
3. Merge the PR to main

#### Production Release Creation (Automated)
- **Publish Production Workflow** automatically:
  1. Creates production tag on main
  2. Creates **draft** production release
  3. Comments on PR with release link

#### Publish Production Release (Manual Step)
1. Navigate to draft release on GitHub
2. Review release notes
3. Publish the release when ready

#### Complete Workflow Summary
```
User: Create v0.1.0-pre pre-release on dev
  ↓ (automatic)
Workflow 1: Validate tag → Create PR
  ↓ (manual)
User: Review and merge PR
  ↓ (automatic)
Workflow 2: Create v0.1.0 tag → Create draft release
  ↓ (manual)
User: Publish production release v0.1.0
```

#### Important Notes
- **Don't edit PR title**: Version is extracted from title format "Release v0.1.0"
- **Don't push to dev during release**: Wait for workflow to complete before adding new commits
- **First release**: First PR from dev → main will include entire codebase, not just docs

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

### Release Automation Pipelines
```
process-prerelease.yml (pre-release automation)
└── process-prerelease (triggered on pre-release published)
    ├── validate pre-release conditions
    │   └── check tag ends with -pre
    ├── checkout dev branch
    ├── validate tag commit on dev
    ├── extract production version
    │   └── strip -pre suffix
    ├── extract changelog section
    └── create PR
        ├── PR: dev → main
        ├── add labels: automated, release
        └── assign repository owner as reviewer

publish-production.yml (production release automation)
└── publish-production (triggered on PR merge to main)
    ├── validate PR conditions
    │   ├── check PR merged (not closed)
    │   └── check has 'release' label
    ├── extract version from PR title
    │   └── validate format: v0.1.0
    ├── get pre-release notes
    │   ├── find pre-release: v{version}-pre
    │   └── fallback to generic notes if not found
    ├── create production tag on main
    ├── create draft production release
    │   └── copy notes from pre-release
    └── comment on PR with release link
```
