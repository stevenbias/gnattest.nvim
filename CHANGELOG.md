# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.2.0 (2026-02-24)

### Feat

- Disable ro protection if user is in a test file
- Add a parameter to refresh xml_info
- Check ro protection in case it is disable afterwards
- Add function to clear and refresh read_only module
- Add command to run test corresponding to subprogram under cursor
- Add a function to split name and extension from a filename
- Fix the get_test_from_line function
- Prepare execution tests
- Set test results in qflist and navigate to test from it
- Add function to prepare quickfix item
- Get test info from filename and line number
- WIP add tests results in quickfix list
- Run package tests is now possible

### Fix

- Config settings are correctly updated
- **Conform.nvim**: Workaround to avoid issue with conform when formatting with gnatformat
- Modif generate cmd
- Fix conflict with other plugin which configure als
- **health**: Check project detection fixed

### Refactor

- Improve the read only reset after test generation
- Modif after review
- Streamline fix after tests
- Refresh read_only module each time we enter in a test file
- Use actual buffer ID instead of default value
- Add missing test condition
- Add a test after find_file return
- Modif after code review
- Now run all tests with ":Gnattest run" cmd without arg
- Handle run tests and results in impl_run function
- Handle qf items list globally
- WIP Improve message in qflist
- Move get_gnattest_info_on_cursor to xml.lua file
- Improve get_gnattest_info_on_line function
- Move get_subprogram_name_from_line to ada_ls
- Simplify condition
- Wait for end of test build before continuing
- Do not run tests if building tests fails
- Use vim.system for building tests
- Hanlde all|pkg|unit tests in same way
- Modif to retrieve test info from cursor of line
- Use vim.system instead of vim.cmd for run_all cmd
- prepare run subp and run all package cmds
- Do not send warning if other LSP are enabled

## v0.1.0 (2025-01-04)

First public release.

### Added
- Read-only region protection for auto-generated test code
- Source ↔ Test navigation using LSP integration
- GNATtest command integration: `generate`, `build`, `run`, `run_all`, `clean`, `switch`
- Visual syntax highlighting for protected regions (🔒 icon)
- XML parsing for GNATtest metadata extraction
- Tab completion for commands and arguments
- Health check module (`:checkhealth gnattest`) for setup verification
- Comprehensive test suite (99.83% coverage)
- Full CI/CD pipeline (formatting, linting, testing)
- AI-generated tests and documentation

### Documentation
- README.md - User guide
- doc/gnattest.txt - Vim help documentation
- CONTRIBUTING.md - Contributor guidelines
- AGENTS.md - Development documentation

## 0.0.0 (2025-11-02)
