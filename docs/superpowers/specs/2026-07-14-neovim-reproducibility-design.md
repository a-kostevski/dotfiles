# Neovim reproducibility design

**Date:** 2026-07-14

## Goal

Make the Neovim configuration reproducible across fresh installs and CI while
keeping normal language defaults and the existing user-facing configuration
scope intact.

## Decisions

- Commit `config/nvim/lazy-lock.json` and pin the bootstrap copy of lazy.nvim
  to an immutable revision. `:Lazy restore` is the recovery/bootstrap command;
  plugin updates are intentional operations that update the pinned lazy.nvim
  revision (when needed) and lockfile together.
- Do not add a Mason version manifest. Mason tool changes stay manual and
  documented: maintainers deliberately refresh its registry and update the
  tools they need. CI and the smoke test must never install Mason tools.
- Use a temporary XDG environment in CI. On a cache miss, a dedicated setup
  step restores plugins from the committed lockfile with tightly scoped network
  access. The assertion step is offline by configuration: it cannot install
  missing plugins, check for updates, refresh Mason, or reuse any developer
  state.
- Pin CI to checksum-verified official Neovim 0.11.4 archives on both Ubuntu
  and macOS. The test does not need language-server executables.
- Keep the whole neotest adapter plugin basename. For example,
  `nvim-neotest/neotest-python` resolves through `require("neotest-python")`.
  A separate per-language module field is unnecessary.
- Exercise Python, JavaScript, Docker, JSON, and YAML through an explicitly
  named smoke-test environment flag only. Production defaults remain Lua,
  Terraform, and C++.
- Make JSON and YAML SchemaStore data part of their native LSP `settings`.
  Retain Neovim's native `before_init` for Pyright, deriving its virtualenv
  interpreter from `config.root_dir`; remove ignored lspconfig-only fields.
- Standardize the Python provider on
  `vim.fn.stdpath("data") .. "/nvim-venv/bin/python"`. The documented setup
  uses idempotent `uv venv --allow-existing` plus `uv pip install --upgrade
  pynvim`.

## Alternatives considered

1. Vendor every plugin archive. This makes the assertion phase completely
   offline but makes the dotfiles repository large and upgrades cumbersome.
2. Publish a prepared plugin artifact. This keeps CI offline but adds an
   opaque artifact lifecycle outside the lockfile reviewers inspect.
3. Commit the lockfile and cache an isolated restored plugin directory. This
   gives reviewers a small, explicit source of truth and limits network access
   to a cache-miss preparation step. This is the selected approach.

## Components and data flow

1. `lazy.lua` bootstraps an immutable lazy.nvim revision, honors the committed
   lockfile, and exposes a smoke-only offline mode. The normal user path keeps
   its existing behavior except for the reproducible revisions.
2. The CI preparation command creates a temporary `XDG_CONFIG_HOME` link to
   the repository configuration and a temporary `XDG_DATA_HOME`. It restores
   plugins with `:Lazy! restore` and caches the resulting lazy directory using
   the OS, Neovim version, bootstrap revision, and lockfile hash.
3. The smoke command uses that populated cache with the offline environment
   flag. It loads the actual configuration and selected lazy plugins, then
   checks the dormant language configurations directly. It fails on a missing
   adapter module, invalid Docker spec, absent SchemaStore enrichment,
   non-native Pyright configuration, or an incorrect provider path. It does
   not open a source buffer or launch an LSP executable.
4. Mason sees the same smoke flag and never refreshes a registry or schedules
   an installation. This is essential because headless mason-lspconfig skips
   its normal `ensure_installed` path and therefore cannot prove tool setup.

## Targeted fixes

- **NVIM-03:** preserve `neotest-*` adapter module names in the declarative
  language helper.
- **NVIM-04:** replace the corrupted Docker configuration with Dockerfile and
  Compose filetypes, `dockerls`, Docker formatter/linter choices, and the
  Docker tree-sitter parser.
- **NVIM-05:** eliminate `on_new_config` and legacy debounce configuration;
  use native settings and supported lifecycle callback semantics.
- **NVIM-07:** use the XDG-derived `nvim-venv` provider location in both
  configuration and setup instructions.

## Formatting and documentation

After functional changes are verified, run one mechanical whole-tree StyLua
pass and add `stylua --check config/nvim` to CI. The functional change and the
formatting pass are intentionally separate review units. Documentation will
cover restore, intentional plugin/Mason updates, and the provider setup and
health check. It will not reconcile unrelated language or AI documentation.

## Verification

- `luac -p` continues to parse every Lua file.
- `stylua --check config/nvim` passes after the isolated reformat.
- `make test` remains green.
- The CI smoke job runs on Ubuntu and macOS with Neovim 0.11.4, restores the
  committed lockfile only on a cache miss, and makes all configuration
  assertions with Mason and plugin mutation disabled.

## Commit and review-status handling

The task explicitly forbids commits unless separately requested. Therefore
this work remains uncommitted on the feature branch, including this spec. The
review report must not claim entries are resolved until actual fixing commit
hashes exist; the required `Resolved: <date> by <commit>` entries are deferred
to that commit step.
