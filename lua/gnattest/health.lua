local M = {}

local function check_executable(cmd, opts)
  opts = opts or {}
  local found = vim.fn.executable(cmd) == 1

  if found then
    local version_cmd = opts.version_arg or "--version"
    local version_result = vim.fn.system(cmd .. " " .. version_cmd .. " 2>&1")
    local version_line = vim.split(version_result, "\n")[1] or ""
    local version = vim.trim(version_line)
    vim.health.ok(string.format("`%s` found (%s)", cmd, version))
    return true
  else
    if opts.optional then
      vim.health.warn(string.format("`%s` not found", cmd), opts.advice or {})
    else
      vim.health.error(
        string.format("`%s` not found", cmd),
        opts.advice or { "Install it with your package manager" }
      )
    end
    return false
  end
end

local function check_treesitter_parser(lang)
  local ok, parser = pcall(vim.treesitter.language.inspect, lang)
  if ok and parser then
    vim.health.ok(string.format("`%s` parser installed", lang))
    return true
  else
    vim.health.error(
      string.format("`%s` parser not installed", lang),
      { string.format("Run :TSInstall %s", lang) }
    )
    return false
  end
end

local function check_lsp_client()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "als" })

  if #clients > 0 then
    local client = clients[1]
    local root_dir = client.config.root_dir or "unknown"
    vim.health.ok(
      string.format("Ada Language Server running (root: %s)", root_dir)
    )
    return true, client
  else
    vim.health.error("Ada Language Server not running", {
      "Configure Ada Language Server first",
      "See: https://github.com/AdaCore/ada_language_server",
    })
    return false, nil
  end
end

local function is_gnattest_project()
  local cwd = vim.fn.getcwd()

  local gnattest_dirs = vim.fs.find(function(name, path)
    return name == "gnattest"
      or (name == "gnattest" and path:match("obj"))
      or name == "tests"
  end, { path = cwd, type = "directory", limit = 3 })

  return #gnattest_dirs > 0
end

local function check_project_structure()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filetype = vim.bo.filetype

  if filetype ~= "ada" then
    vim.health.info("Not in an Ada buffer - skipping project-specific checks")
    return
  end

  if not bufname or bufname == "" then
    vim.health.info("No file loaded - skipping project checks")
    return
  end

  local lsp_ok, client = check_lsp_client()

  if not lsp_ok then
    return
  end

  local project_file = nil
  if client and client.config.root_dir then
    local json_file = client.config.root_dir .. "/.als.json"
    local ok, content = pcall(vim.fn.readfile, json_file)
    if ok then
      local json = vim.fn.json_decode(content)
      if json and json.projectFile then
        project_file = json.projectFile
        vim.health.ok(
          string.format("GNAT project file found (%s)", project_file)
        )
      end
    end
  end

  if not project_file then
    vim.health.warn("GNAT project file (.gpr) not detected", {
      "GNATtest requires a GNAT project file",
      "Ensure your project has a .gpr file configured",
    })
  end

  if is_gnattest_project() then
    vim.health.ok("GNATtest project structure detected")

    local xml_file = vim.fs.find("gnattest.xml", {
      path = client.config.root_dir,
      type = "file",
    })[1]

    if xml_file then
      vim.health.ok("gnattest.xml found (tests have been generated)")
    else
      vim.health.info(
        "gnattest.xml not found (run :Gnattest generate to create tests)"
      )
    end
  else
    vim.health.info("GNATtest project structure not detected", {
      "This may be a regular Ada project without GNATtest",
      "Run :Gnattest generate to create test harness",
    })
  end
end

local function check_config()
  local config = require("gnattest.config").get()

  vim.health.info(
    string.format("highlight.percent = %s", tostring(config.highlight.percent))
  )
  vim.health.info(
    string.format("read_only.enabled = %s", tostring(config.read_only.enabled))
  )

  if type(config.highlight.percent) == "number" then
    vim.health.ok("Configuration is valid")
  else
    vim.health.error("Configuration has invalid types")
  end
end

function M.check()
  vim.health.start("gnattest.nvim: Neovim version")
  if vim.fn.has("nvim-0.10") == 1 then
    local version = vim.version()
    vim.health.ok(
      string.format(
        "Neovim %d.%d.%d",
        version.major,
        version.minor,
        version.patch
      )
    )
  else
    vim.health.error(
      "Neovim >= 0.10 required",
      { "Upgrade Neovim to version 0.10 or newer" }
    )
  end

  vim.health.start("gnattest.nvim: External dependencies")
  check_executable("gnattest", {
    advice = {
      "Install GNATtest (part of GNAT toolchain)",
      "See: https://docs.adacore.com/gnatcoverage-docs/html/gnattest/",
    },
  })
  check_executable("gprbuild", {
    advice = {
      "Install gprbuild (part of GNAT toolchain)",
      "Required for :Gnattest build",
    },
  })
  check_executable("gprclean", {
    advice = {
      "Install gprclean (part of GNAT toolchain)",
      "Required for :Gnattest clean",
    },
  })
  check_executable("git", {
    optional = true,
    advice = { "Git is recommended but not required" },
  })

  vim.health.start("gnattest.nvim: Treesitter parsers")
  check_treesitter_parser("ada")
  check_treesitter_parser("xml")

  vim.health.start("gnattest.nvim: Configuration")
  check_config()

  vim.health.start("gnattest.nvim: Project detection")
  check_project_structure()

  vim.health.start("gnattest.nvim: Plugin status")
  if vim.g.loaded_gnattest then
    vim.health.ok("Plugin loaded")
  else
    vim.health.warn("Plugin not loaded", {
      "Ensure plugin is properly installed",
      "Check that ftplugin/ada.lua can be found",
    })
  end
end

return M
