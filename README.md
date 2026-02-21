# gnattest.nvim

[![CI](https://github.com/StevenBias/gnattest.nvim/workflows/CI/badge.svg)](https://github.com/StevenBias/gnattest.nvim/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg)](https://neovim.io)

Neovim plugin providing [GNATtest](https://github.com/AdaCore/gnattest) workflow integration: generate, build, run, clean tests and navigate between source and test files

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

## Quick Start

1. Open an Ada file in a project
2. Configure Ada Language Server with the correct GPR file
>*Example of `.als.json` configuration:*
`
{
    "projectFile": "/path/to/your/project.gpr"
}
`
3. Generate tests: `:Gnattest generate`
4. Run tests: `:Gnattest run`
>*Tests are built before every run*
5. Review results in the quickfix list
>*Results are sorted with failed tests first and then by filenames and
subprogram line numbers.*

### Requirements

- **Neovim** >= 0.10
- **Ada Language Server** - Must be configured and running ([setup guide](https://github.com/AdaCore/ada_language_server))
- **GNAT** - Must be availabe in the $PATH
- **GNAT Project File** - Only Ada projects using GPR files are supported (GNATtest must be configured in the GPR file)
- **GNATtest** - Unit testing framework for Ada ([user's guide](https://docs.adacore.com/gnatcoverage-docs/html/gnattest/gnattest_part.html#gnattest-user-s-guide) and [Github repo](https://github.com/AdaCore/gnattest))
- **Treesitter parsers**: `ada`, `xml` (`:TSInstall ada xml`)

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
### Health Check

Verify your setup is correct with `:checkhealth gnattest`.
You can switch to `:help gnattest` to get an understanding of
how to use gnattest.nvim and how to configure it.

## Usage

### Commands

All commands are subcommands of `:Gnattest`:
- `:Gnattest generate` - Generate test harness from source files
- `:Gnattest build` - Build the test project
- `:Gnattest run [package[:subprogram]]` - Build tests, then run a specific test, a whole package, or the entire test suite. Results are sent to the quickfix list
- `:Gnattest run_all` - Run entire test suite (deprecated; use `:Gnattest run` with no args). Results are sent to the quickfix list
- `:Gnattest run_cursor` - Run the test corresponding to the current cursor. Results are sent to the quickfix list
- `:Gnattest clean` - Clean test build artifacts
- `:Gnattest switch` - Place cursor on a subprogram and toggle between source and test file

### Keymaps

Suggested mappings (prefix `<leader>t`):

```lua
vim.keymap.set("n", "<leader>tg", "<cmd>Gnattest generate<cr>", { desc = "GNATtest: generate" })
vim.keymap.set("n", "<leader>tb", "<cmd>Gnattest build<cr>", { desc = "GNATtest: build" })
vim.keymap.set("n", "<leader>ta", "<cmd>Gnattest run<cr>", { desc = "GNATtest: run all" })
vim.keymap.set("n", "<leader>tr", "<cmd>Gnattest run_cursor<cr>", { desc = "GNATtest: run cursor" })
vim.keymap.set("n", "<leader>ts", "<cmd>Gnattest switch<cr>", { desc = "GNATtest: switch source/test" })
vim.keymap.set("n", "<leader>tc", "<cmd>Gnattest clean<cr>", { desc = "GNATtest: clean" })
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
- Shows notifications when you attempt to modify protected code
- Prevents editing in these regions (changes are automatically reverted)

The read-only feature can be disabled in the configuration
if you encounter issues with it. To disable read-only protection:
```lua
require("gnattest").setup({
  read_only = {
    enabled = false,
  },
})
```
### Troubleshooting

- Run `:checkhealth gnattest` for a full environment check
- Use `:checkhealth vim.lsp` to verify Ada Language Server is running with
correct settings (`.als.json`) file
- Use `:TSInstallInfo` to confirm `ada` and `xml` parsers are installed
- Ensure `gnattest.xml` exists (generated by `:Gnattest generate`)

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

## About This Project

This is my first public Neovim plugin and part of my learning journey; tests and documentation were generated with AI assistance. Feedback and contributions are welcome.

I created it to:
- Learn modern Neovim plugin development practices
- Improve my Ada development workflow
- Explore LSP integration, Treesitter parsing, and extmarks

### Features

- **Read-only Protection** - Automatically protect auto-generated test regions
- **Navigation** - Jump between source and test files with LSP integration
- **XML Metadata** - Parse `gnattest.xml` for test locations and completion
- **Command Integration** - Run GNATtest directly from Neovim
- **Quickfix Results** - Test run output is summarized in the quickfix list
- **Syntax Highlighting** - Visual indicators for protected code regions
- **Ada Language Server support** - update ALS project context when switching files (source <-> test)
- **Tab Completion** - Command and argument autocompletion

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Related Projects

- [Ada Language Server](https://github.com/AdaCore/ada_language_server) - LSP server for Ada
- [GNATtest User's Guide](https://docs.adacore.com/gnatcoverage-docs/html/gnattest/gnattest_part.html#gnattest-user-s-guide) - Official GNATtest documentation
- [Neovim Best Practices](https://github.com/lumen-oss/nvim-best-practices) - Plugin development guidelines

## License

MIT License - see [LICENSE](LICENSE) for details.
