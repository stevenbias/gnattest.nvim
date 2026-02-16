# GNATtest.nvim

[![CI](https://github.com/StevenBias/gnattest.nvim/workflows/CI/badge.svg)](https://github.com/StevenBias/gnattest.nvim/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg)](https://neovim.io)

> Neovim plugin providing GNATtest workflow integration: generate, build, run, clean tests and navigate between source and test files

## Features

- **Read-only Protection** - Automatically protect auto-generated test regions
- **Navigation** - Jump between source and test files with LSP integration
- **Command Integration** - Run GNATtest directly from Neovim
- **Quickfix Results** - Test run output is summarized in the quickfix list
- **Syntax Highlighting** - Visual indicators for protected code regions
- **Ada Language Server support** - update ALS project context when switching files (source <-> test)
- **Tab Completion** - Command and argument autocompletion

## Demo
### Command Integration

![GNATtest Commands](media/gnattest_cmds.gif)
*Demonstrates available GNATtest commands with tab completion.*

### Navigation & Read-only Protection

![Switch and Protection](media/gnattest_switch_and_protect.gif)
*Shows `:Gnattest switch` to navigate between source and test files, plus read-only region protection in action.*

### Build and Run Specific Test

![Build and Run](media/gnattest_build_and_run.gif)
*Example of building the test project and running a specific test using `:Gnattest run` with package:subprogram syntax.*


## Installation

### lazy.nvim

```lua
{
  "StevenBias/gnattest.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  ft = { "ada" },
}
```

### vim-plug

```vim
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'StevenBias/gnattest.nvim'

lua << EOF
require("gnattest").setup()
EOF
```

## Requirements

- **Neovim** >= 0.10
- **Ada Language Server** - Must be configured and running ([setup guide](https://github.com/AdaCore/ada_language_server))
- **GNAT Project File** - Only Ada projects using `.gpr` files are supported (GNATtest must be configured in the `.gpr` file)
- **GNATtest** - Unit testing framework for Ada ([user's guide](https://docs.adacore.com/gnatcoverage-docs/html/gnattest/gnattest_part.html#gnattest-user-s-guide) and [Github repo](https://github.com/AdaCore/gnattest))
- **Treesitter parsers**: `ada`, `xml` (`:TSInstall ada xml`)

### Health Check

Verify your setup is correct:
```vim
:checkhealth gnattest
```

## Usage

### Commands

All commands are subcommands of `:Gnattest`:
- `:Gnattest generate` - Generate test harness from source files
- `:Gnattest build` - Build the test project
- `:Gnattest run [package[:subprogram]]` - Run a specific test, a whole package, or the entire test suite. Results are sent to the quickfix list
- `:Gnattest run_all` - Run entire test suite (deprecated; use `:Gnattest run` with no args). Results are sent to the quickfix list
- `:Gnattest run_cursor` - Run the test corresponding to the current cursor. Results are sent to the quickfix list
- `:Gnattest clean` - Clean test build artifacts
- `:Gnattest switch` - Toggle between source and test file

### Examples

**Generate and run tests:**
```vim
:Gnattest generate
:Gnattest build
:Gnattest run
```

**Navigate to a specific test:**
```vim
" Place cursor on a subprogram in your source file
:Gnattest switch
" You'll be taken to the corresponding test file
```

**Run a specific test:**
```vim
:Gnattest run Board:Init
" Tab completion available for package:subprogram names
```

**Run the test at the cursor:**
```vim
:Gnattest run_cursor
```

### Read-only Protection
> **⚠️ Disclaimer:** The read-only protection feature is provided as-is. While it 
works in most common scenarios, there may be edge cases or unknown issues where 
protection could fail. Always verify that protected regions remain intact, 
especially before committing changes. Use version control to safeguard your work.

GNATtest generates test harnesses with protected regions marked by comments:
```ada
--  begin read only
   -- Auto-generated code here
--  end read only
```

The plugin automatically:
- Highlights these regions with a 🔒 icon
- Prevents editing (changes are automatically reverted)
- Shows notifications when you attempt to modify protected code

## Configuration

### Available Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `highlight.percent` | number | `3` | Brightness adjustment for protected region highlighting |
| `read_only.enabled` | boolean | `true` | Enable/disable read-only protection |

### Default Configuration

```lua
require("gnattest").setup({
  highlight = {
    percent = 3,
  },
  read_only = {
    enabled = true,
  },
})
```

### Example: Disable Read-only Protection

```lua
require("gnattest").setup({
  read_only = {
    enabled = false,
  },
})
```

## About This Project

This is my first public Neovim plugin. I created it to:
- Learn modern Neovim plugin development practices
- Improve my Ada development workflow
- Explore LSP integration, Treesitter parsing, and extmarks

### Development Notes

Tests and documentation were generated with AI assistance.\
While functional and well-tested, this plugin reflects my learning journey. 
Feedback and contributions are welcome.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Related Projects

- [Ada Language Server](https://github.com/AdaCore/ada_language_server) - LSP server for Ada
- [GNATtest User's Guide](https://docs.adacore.com/gnatcoverage-docs/html/gnattest/gnattest_part.html#gnattest-user-s-guide) - Official GNATtest documentation
- [Neovim Best Practices](https://github.com/lumen-oss/nvim-best-practices) - Plugin development guidelines

## License

MIT License - see [LICENSE](LICENSE) for details.
