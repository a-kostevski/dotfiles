# Neovim Reproducibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Neovim setup reproducible from a committed plugin lockfile and prove its real configuration graph in a pinned, cross-platform headless smoke test.

**Architecture:** lazy.nvim and every configured plugin resolve from a committed lockfile, while the lazy.nvim manager itself resolves from one immutable commit. A CI cache-miss step restores that graph under an isolated XDG data directory; a separate offline smoke step starts the real config, loads selected lazy modules, and asserts the dormant language paths without installing Mason tools or starting a language server.

**Tech Stack:** Neovim 0.11.4, Lua/LuaJIT, lazy.nvim, mason.nvim, GitHub Actions cache, Bash, StyLua, uv/pynvim.

## Global Constraints

- Work only from `config/nvim/` sources; never edit `~/.config/`.
- Normal enabled languages remain Lua, Terraform, and C++; Python, JavaScript,
  Docker, JSON, and YAML exist only in the explicitly named smoke-test overlay.
- The lazy.nvim bootstrap revision is `85c7ff3711b730b4030d03144f6db6375044ae82`.
- CI uses Neovim `0.11.4`, not the runner-provided `nvim`.
- The CI artifact checksums are:
  - Linux x86_64: `a74740047e73b2b380d63a474282814063d10650cd6cc95efa16d1713c7e616c`
  - macOS x86_64: `567b89138c29386f67a00fc8e26c6469c8bf0e5707dfea5e3fbaf4e21294d9eb`
  - macOS arm64: `2de9623a4aa8cedf85c51e33bf8e85e05f6f291b923cd666c04704ccf164e8b7`
- A smoke run must not install missing plugins, check/update plugins, refresh the
  Mason registry, or install Mason packages. It must not require an LSP binary.
- `make test`, Lua 5.3 parsing, and `stylua --check config/nvim` must pass.
- The user has explicitly withheld commit and push authority. Do not commit or
  add `Resolved: ... by <commit>` review markers; preserve logical change
  boundaries in the working tree for a later authorized commit sequence.

---

## File structure

| File | Responsibility |
| --- | --- |
| `config/nvim/lua/kostevski/config/lazy.lua` | Pin and bootstrap lazy.nvim; turn automatic mutation off in smoke mode; point lazy at the tracked lockfile. |
| `config/nvim/lua/kostevski/config/languages.lua` | Select the extra smoke-only languages from a named environment variable without changing normal defaults. |
| `config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua` | Prevent Mason registry refresh/install side effects during smoke mode. |
| `config/nvim/lua/kostevski/utils/lang.lua` | Preserve neotest module basenames and allow per-filetype formatter/linter mappings. |
| `config/nvim/lua/kostevski/plugins/lang/docker.lua` | Define real Dockerfile/Compose language support. |
| `config/nvim/lsp/jsonls.lua`, `yamlls.lua`, `pyright.lua` | Use native LSP settings and callback semantics. |
| `config/nvim/lua/kostevski/config/options.lua` | Configure the XDG-derived pynvim executable. |
| `config/nvim/lazy-lock.json` | Record exact plugin commits, including smoke-only dependency modules. |
| `tests/test-nvim-smoke.sh` | Build an isolated XDG environment; either sync/restore plugins or execute the offline assertion script. |
| `tests/nvim/smoke.lua` | Assert config startup, adapter module resolution, Docker spec contents, native LSP settings, and provider path. |
| `.github/workflows/ci.yml` | Install the pinned Neovim archive, cache restored plugins, run smoke tests on both platforms, and enforce StyLua. |
| `README.md` | Document restore, intentional plugin/Mason updates, and the idempotent provider setup. |
| `docs/REVIEW-2026-07-14.md` | Mark only entries with real commit hashes, after commit authority is given. |

## Task 1: Establish the isolated lockfile and smoke-test harness

**Files:**

- Create: `tests/test-nvim-smoke.sh`
- Create: `tests/nvim/smoke.lua`
- Modify: `config/nvim/lua/kostevski/config/lazy.lua`
- Modify: `config/nvim/lua/kostevski/config/languages.lua`
- Modify: `config/nvim/lua/kostevski/plugins/lsp/lspconfig.lua`
- Create: `config/nvim/lazy-lock.json` (generated, never hand-authored)

**Interfaces:**

- Consumes: `NVIM_BIN`, `NVIM_SMOKE_STATE`, `DOTFILES_NVIM_SMOKE`,
  `DOTFILES_NVIM_OFFLINE`, and `DOTFILES_NVIM_SMOKE_LANGUAGES` environment
  variables.
- Produces: `tests/test-nvim-smoke.sh --sync`, `--restore`, and default
  assertion modes. CI calls `--restore` only on a cache miss and default mode
  once the cache is present.

- [ ] **Step 1: Write the assertion program before its dependencies exist**

Create `tests/nvim/smoke.lua` with a fail-fast assertion helper and checks that
will expose the current defects once plugins are restored:

```lua
local function expect(condition, message)
  if not condition then
    error("nvim smoke test: " .. message)
  end
end

local function expect_equal(actual, expected, message)
  expect(actual == expected, string.format("%s (expected %s, got %s)", message, expected, actual))
end

local function plugin_spec(specs, name)
  for _, spec in ipairs(specs) do
    if spec[1] == name then
      return spec
    end
  end
  error("nvim smoke test: missing plugin spec " .. name)
end

local function apply_opts(spec)
  local opts = {}
  if type(spec.opts) == "function" then
    spec.opts(nil, opts)
  elseif type(spec.opts) == "table" then
    opts = vim.deepcopy(spec.opts)
  end
  return opts
end

expect(vim.env.DOTFILES_NVIM_SMOKE == "1", "requires DOTFILES_NVIM_SMOKE=1")
expect(vim.env.DOTFILES_NVIM_OFFLINE == "1", "requires DOTFILES_NVIM_OFFLINE=1")

-- The existing helper currently tries require("python") and require("jest").
apply_opts(plugin_spec(require("kostevski.plugins.lang.python"), "nvim-neotest/neotest"))
apply_opts(plugin_spec(require("kostevski.plugins.lang.javascript"), "nvim-neotest/neotest"))

local docker = apply_opts(plugin_spec(require("kostevski.plugins.lang.docker"), "neovim/nvim-lspconfig"))
local docker_config = docker.servers.docker_language_server
expect(docker_config ~= nil, "Docker must configure docker_language_server")
expect(vim.tbl_contains(docker_config.filetypes, "dockerfile"), "Dockerfile filetype missing")
expect(vim.tbl_contains(docker_config.filetypes, "yaml.docker-compose"), "Compose filetype missing")

require("lspconfig")
local jsonls = vim.lsp.config.jsonls
local yamlls = vim.lsp.config.yamlls
local pyright = vim.deepcopy(vim.lsp.config.pyright)
expect(#jsonls.settings.json.schemas > 0, "jsonls has no SchemaStore schemas")
expect(next(yamlls.settings.yaml.schemas) ~= nil, "yamlls has no SchemaStore schemas")
expect(pyright.flags == nil, "pyright retains legacy flags")
pyright.root_dir = "/tmp/nvim-smoke-project"
pyright.before_init({}, pyright)
expect_equal(
  pyright.settings.python.pythonPath,
  "/tmp/nvim-smoke-project/.venv/bin/python",
  "pyright did not derive pythonPath from root_dir"
)

expect_equal(
  vim.g.python3_host_prog,
  vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-venv", "bin", "python"),
  "python provider is not XDG-derived"
)
```

- [ ] **Step 2: Add a portable isolated-XDG launcher**

Create executable `tests/test-nvim-smoke.sh`. It must resolve the physical repo
root, create only `${NVIM_SMOKE_STATE:?}/home`, `config`, `data`, and `state`,
and symlink `config/nvim` below that temporary config root. Its three explicit
modes are:

```bash
case "${1:-smoke}" in
  --sync)
    DOTFILES_NVIM_SMOKE=1 "$NVIM_BIN" --headless '+Lazy! sync' +qa
    ;;
  --restore)
    DOTFILES_NVIM_SMOKE=1 "$NVIM_BIN" --headless '+Lazy! restore' +qa
    ;;
  smoke)
    DOTFILES_NVIM_SMOKE=1 DOTFILES_NVIM_OFFLINE=1 \
      "$NVIM_BIN" --headless \
      "+lua dofile(vim.env.DOTFILES_REPO_ROOT .. '/tests/nvim/smoke.lua')" +qa
    ;;
  *)
    printf 'usage: %s [--sync|--restore]\n' "$0" >&2
    exit 64
    ;;
esac
```

Export the following before this block:

```bash
export HOME="$NVIM_SMOKE_STATE/home"
export XDG_CONFIG_HOME="$NVIM_SMOKE_STATE/config"
export XDG_DATA_HOME="$NVIM_SMOKE_STATE/data"
export XDG_STATE_HOME="$NVIM_SMOKE_STATE/state"
export DOTFILES_REPO_ROOT="$REPO_ROOT"
export DOTFILES_NVIM_SMOKE_LANGUAGES='lua,terraform,cpp,python,javascript,docker,json,yaml'
```

A caller-supplied `NVIM_SMOKE_STATE` is always retained for `--restore` then
`smoke` reuse; only a directory created by the launcher is cleaned up. CI
sets `NVIM_SMOKE_KEEP_STATE=1` to retain a launcher-created state directory
for `actions/cache`.

- [ ] **Step 3: Run the assertion command and record the expected failure**

Run with a deliberately empty temporary data directory:

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" tests/test-nvim-smoke.sh
```

Expected: non-zero status because offline mode rejects a missing lazy.nvim
manager/plugins. This proves the runner does not silently reuse the developer's
Neovim state.

- [ ] **Step 4: Pin lazy.nvim and add test-only mutation controls**

In `lazy.lua`, replace the moving `--branch=stable` bootstrap with an immutable
commit constant and an offline guard. The key behavior is:

```lua
local LAZY_REVISION = "85c7ff3711b730b4030d03144f6db6375044ae82"
local offline = vim.env.DOTFILES_NVIM_OFFLINE == "1"

if not vim.uv.fs_stat(lazypath) then
  assert(not offline, "lazy.nvim is absent in offline mode; run :Lazy restore first")
  -- clone without --branch, then check out LAZY_REVISION below
end

local revision = vim.fn.system({ "git", "-C", lazypath, "rev-parse", "HEAD" }):gsub("%s+$", "")
if revision ~= LAZY_REVISION then
  assert(not offline, "lazy.nvim revision differs in offline mode; run :Lazy restore first")
  -- fetch LAZY_REVISION only in the explicit online path, then detached-checkout it
end

require("lazy").setup({
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
  install = { missing = not offline },
  checker = { enabled = not offline, notify = false, frequency = 86400 },
  change_detection = { enabled = not offline, notify = false },
  -- retain the existing spec/defaults/performance configuration
})
```

Do not fetch on every startup: fetch only when the installed manager does not
match the tracked revision. The failure message must tell an offline caller to
run the documented restore procedure.

In `languages.lua`, use the smoke list only when its opt-in variable exists:

```lua
local smoke_languages = vim.env.DOTFILES_NVIM_SMOKE_LANGUAGES
local enabled = smoke_languages and vim.split(smoke_languages, ",", { trimempty = true })
  or { "lua", "terraform", "cpp" }

return { enabled = enabled, overrides = {} }
```

In the Mason `config` function, call `require("mason").setup(opts)` but return
before `mason-registry.refresh` when `DOTFILES_NVIM_SMOKE == "1"`:

```lua
if vim.env.DOTFILES_NVIM_SMOKE == "1" then
  return
end
```

- [ ] **Step 5: Generate the real lockfile in temporary state**

Use a temporary XDG tree, never `~/.local/share/nvim`:

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --sync
git diff --check -- config/nvim/lazy-lock.json
```

Expected: `config/nvim/lazy-lock.json` is created and every entry has a
repository branch and full commit hash. Review it with:

```bash
jq -S . config/nvim/lazy-lock.json
```

The smoke language list must make the lockfile include `neotest-python`,
`neotest-jest`, `SchemaStore.nvim`, and all normal enabled-plugin dependencies.

- [ ] **Step 6: Verify the first meaningful failure**

Populate a second temporary state directory from the lockfile, then run the
offline assertions:

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --restore
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh
```

Expected: non-zero status at the Python or JavaScript neotest adapter assertion
because the existing helper requests `python`/`jest` rather than the real
plugin modules. Preserve this output for the Task 2 regression proof.

## Task 2: Correct dormant language, native-LSP, and provider configuration

**Files:**

- Modify: `config/nvim/lua/kostevski/utils/lang.lua`
- Modify: `config/nvim/lua/kostevski/plugins/lang/docker.lua`
- Modify: `config/nvim/lsp/jsonls.lua`
- Modify: `config/nvim/lsp/yamlls.lua`
- Modify: `config/nvim/lsp/pyright.lua`
- Modify: `config/nvim/lua/kostevski/config/options.lua`
- Test: `tests/nvim/smoke.lua`

**Interfaces:**

- Consumes: the Task 1 smoke language overlay and locked adapter plugins.
- Produces: valid lazy specs for `neotest-python`, `neotest-jest`, and
  `docker_language_server`; native `vim.lsp.config` tables that the smoke
  program can inspect without spawning a server process.

- [ ] **Step 1: Keep neotest adapter Lua module names intact**

Replace the adapter loop in `M.register` with this exact basename handling:

```lua
for _, adapter in ipairs(def.test_adapters) do
  local module = adapter:match("([^/]+)$")
  table.insert(opts.adapters, require(module))
end
```

Do not add a `test_adapter_module` field: the lazy plugin basename is already
the canonical module name for the configured adapters.

- [ ] **Step 2: Add per-filetype formatter and linter support to the declarative helper**

When merging `formatters_by_ft` and `linters_by_ft`, prefer a supplied mapping
and otherwise retain the existing list for every declared filetype:

```lua
opts.formatters_by_ft[ft] = (def.formatters.by_ft and def.formatters.by_ft[ft]) or def.formatters.list
opts.linters_by_ft[ft] = (def.linters.by_ft and def.linters.by_ft[ft]) or def.linters.list or {}
```

Document `by_ft?: table<string, string[]>` beside the existing formatter and
linter type annotations. This is necessary to avoid running Dockerfile-only
tools against Compose YAML.

- [ ] **Step 3: Replace the corrupted Docker definition**

Use a normal `lang.register` table with these values:

```lua
{
  name = "docker",
  filetypes = { "dockerfile", "yaml.docker-compose" },
  root_markers = {
    "Dockerfile", "docker-compose.yaml", "docker-compose.yml",
    "compose.yaml", "compose.yml", "docker-bake.json", "docker-bake.hcl",
    "docker-bake.override.json", "docker-bake.override.hcl", ".git",
  },
  lsp_server = "docker_language_server",
  formatters = {
    list = {},
    tools = { "dockerfmt", "yamlfmt" },
    by_ft = {
      dockerfile = { "dockerfmt" },
      ["yaml.docker-compose"] = { "yamlfmt" },
    },
  },
  linters = {
    list = {},
    tools = { "hadolint" },
    by_ft = { dockerfile = { "hadolint" } },
  },
  treesitter_parsers = { "dockerfile", "yaml" },
}
```

Remove `isobit/vim-caddyfile`, `gopls`, Go formatters, Caddy filetypes, and
all unrelated markers. `docker_language_server` starts the documented
`docker-language-server start --stdio` command through current nvim-lspconfig;
Mason maps it to the `docker-language-server` package. `dockerfmt`, `yamlfmt`,
and `hadolint` remain deliberate Mason tools only when Docker support is
enabled, not smoke-test requirements.

- [ ] **Step 4: Move SchemaStore data into native LSP settings**

Replace both `on_new_config` callbacks with eager `settings` values, so native
`vim.lsp.config` receives the data without lspconfig-only hooks:

```lua
-- jsonls.lua
settings = {
  json = {
    schemas = require("schemastore").json.schemas(),
    format = { enable = true },
    validate = { enable = true },
  },
}

-- yamlls.lua
settings = {
  redhat = { telemetry = { enabled = false } },
  yaml = {
    schemas = require("schemastore").yaml.schemas(),
    keyOrdering = false,
    format = { enable = true },
    validate = true,
    schemaStore = { enable = false, url = "" },
  },
}
```

Keep the current `cmd`, `filetypes`, root markers, telemetry, validation, and
format configuration unchanged.

- [ ] **Step 5: Use supported Pyright callback data and remove the legacy flag**

Retain `before_init`, which Neovim 0.11 supports, but use the resolved root
rather than the process working directory:

```lua
before_init = function(_, config)
  local root = config.root_dir or vim.fn.getcwd()
  config.settings.python.pythonPath = vim.fs.joinpath(root, ".venv", "bin", "python")
end,
```

Delete the entire `flags = { debounce_text_changes = 150 }` table. Keep the
existing `on_attach` commands and `set_python_path` behavior.

- [ ] **Step 6: Standardize the Python provider path**

Replace the hard-coded home-relative uv path in `options.lua` with:

```lua
vim.g.python3_host_prog = vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-venv", "bin", "python")
```

- [ ] **Step 7: Run the locked, offline smoke regression**

Use a fresh isolated state and no Mason packages:

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --restore
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh
```

Expected: exit status 0. If it fails, keep the state directory and inspect
`$state_dir/state/nvim/lsp.log`; do not fall back to the developer's real XDG
directories or install Mason tools to make it pass.

## Task 3: Make the CI smoke test deterministic and document recovery policy

**Files:**

- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `config/nvim/lazy-lock.json` only if Task 2 changed the plugin graph

**Interfaces:**

- Consumes: `tests/test-nvim-smoke.sh`, the committed lockfile, lazy revision
  `85c7ff3711b730b4030d03144f6db6375044ae82`, and the artifact checksum
  constants above.
- Produces: a `nvim-smoke` Ubuntu/macOS CI job with a network-limited restore
  phase followed by the assertion phase.

- [ ] **Step 1: Add a pinned Neovim installer step to the CI matrix**

Add a `nvim-smoke` job with `matrix.os: [ubuntu-latest, macos-latest]`. Its
installer must select the native archive and validate its hash before adding it
to `GITHUB_PATH`:

```bash
version=0.11.4
case "${RUNNER_OS}:$(uname -m)" in
  Linux:x86_64)
    archive=nvim-linux-x86_64.tar.gz
    sha256=a74740047e73b2b380d63a474282814063d10650cd6cc95efa16d1713c7e616c
    ;;
  macOS:x86_64)
    archive=nvim-macos-x86_64.tar.gz
    sha256=567b89138c29386f67a00fc8e26c6469c8bf0e5707dfea5e3fbaf4e21294d9eb
    ;;
  macOS:arm64)
    archive=nvim-macos-arm64.tar.gz
    sha256=2de9623a4aa8cedf85c51e33bf8e85e05f6f291b923cd666c04704ccf164e8b7
    ;;
  *) printf 'unsupported smoke-test platform: %s:%s\n' "$RUNNER_OS" "$(uname -m)" >&2; exit 1 ;;
esac
curl --fail --location --retry 3 --output "$RUNNER_TEMP/$archive" \
  "https://github.com/neovim/neovim/releases/download/v${version}/$archive"
printf '%s  %s\n' "$sha256" "$RUNNER_TEMP/$archive" | \
  { command -v sha256sum >/dev/null && sha256sum -c - || shasum -a 256 -c -; }
tar -xzf "$RUNNER_TEMP/$archive" -C "$RUNNER_TEMP"
echo "$RUNNER_TEMP/${archive%.tar.gz}/bin" >> "$GITHUB_PATH"
```

Run `nvim --version | head -1` immediately after installation and require
`NVIM v0.11.4` in its output.

- [ ] **Step 2: Cache only the isolated plugin data and restore only on misses**

Create `$RUNNER_TEMP/nvim-smoke`, then use `actions/cache@v5` with:

```yaml
- name: Restore locked lazy.nvim plugins
  id: nvim-plugin-cache
  uses: actions/cache@v5
  with:
    path: ${{ runner.temp }}/nvim-smoke/data/nvim/lazy
    key: nvim-smoke-${{ runner.os }}-0.11.4-85c7ff3711b730b4030d03144f6db6375044ae82-${{ hashFiles('config/nvim/lazy-lock.json') }}

- name: Restore plugins from lazy-lock.json (cache miss only)
  if: steps.nvim-plugin-cache.outputs.cache-hit != 'true'
  env:
    NVIM_BIN: nvim
    NVIM_SMOKE_STATE: ${{ runner.temp }}/nvim-smoke
    NVIM_SMOKE_KEEP_STATE: '1'
  run: tests/test-nvim-smoke.sh --restore
```

The only plugin-network operation is the cache-miss restore command. Do not add
Mason to the cache and do not use `:Lazy sync` in CI.

- [ ] **Step 3: Add the offline smoke assertion step**

After the cache/restore, add:

```yaml
- name: Load locked Neovim configuration offline
  env:
    NVIM_BIN: nvim
    NVIM_SMOKE_STATE: ${{ runner.temp }}/nvim-smoke
    NVIM_SMOKE_KEEP_STATE: '1'
  run: tests/test-nvim-smoke.sh
```

This command sets `DOTFILES_NVIM_OFFLINE=1` internally. A missing lazy manager,
plugin, adapter module, or LSP configuration must fail this command rather than
attempting recovery over the network.

- [ ] **Step 4: Add the documented plugin and Mason maintenance workflow**

In the Neovim setup section of `README.md`, add these exact distinctions:

```markdown
### Reproducible plugin recovery

After syncing this configuration on a new or repaired machine, open Neovim and
run `:Lazy restore`. It installs the revisions in `config/nvim/lazy-lock.json`.

### Intentional updates

Update plugins only when you intend to review a dependency change: run
`:Lazy update`, inspect `config/nvim/lazy-lock.json`, run the smoke test, and
commit the lockfile with the related configuration change. Update the pinned
lazy.nvim bootstrap revision in `lazy.lua` in the same change when upgrading
the manager.

Mason tools are deliberately not version-pinned. Run `:MasonUpdate` and update
or install a needed tool only when you choose to do so; verify the affected
language locally. CI does not install or update Mason tools.
```

Because the smoke overlay adds disabled-language dependencies to the lockfile,
also document the maintainer command that refreshes every pinned entry:

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --sync
```

- [ ] **Step 5: Document and verify the idempotent pynvim provider setup**

Replace the existing Python provider instructions with:

```bash
NVIM_VENV="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/nvim-venv"
uv venv --allow-existing "$NVIM_VENV"
uv pip install --python "$NVIM_VENV/bin/python" --upgrade pynvim
```

Then document the verification command exactly as `:checkhealth provider`.
For a local verification, run the commands above once, start Neovim normally,
and confirm the Python provider health check is successful. Do not run it with
the CI smoke XDG state, which intentionally has no provider virtualenv.

- [ ] **Step 6: Re-run the smoke test using the exact CI flow locally**

```bash
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --restore
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh
```

Expected: zero exit status without `MasonInstall`, a language-server process,
or mutation outside `state_dir` and the generated lockfile.

## Task 4: Apply and enforce the declared StyLua policy

**Files:**

- Modify: every Lua file under `config/nvim/` only as StyLua rewrites it
- Modify: `.github/workflows/ci.yml`

**Interfaces:**

- Consumes: `config/nvim/stylua.toml` (two-space indentation).
- Produces: an all-clean `stylua --check config/nvim` tree and a CI formatting
  gate that catches further drift.

- [ ] **Step 1: Capture the functional diff boundary**

Before formatting, save the list of functional files and verify their smoke
test status:

```bash
git diff --name-only -- config/nvim tests .github/workflows/ci.yml README.md
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$(mktemp -d)" tests/test-nvim-smoke.sh --restore
```

Expected: the pre-format functional set is known and the restored graph is
testable. Do not mix hand-edited logic with the formatter pass afterward.

- [ ] **Step 2: Run one mechanical whole-tree format pass**

```bash
stylua config/nvim
stylua --check config/nvim
```

Expected: the second command exits 0. Inspect the diff and confirm every
Lua-only change outside the functional boundary is whitespace/layout generated
by StyLua; do not manually “improve” any configuration in this step.

- [ ] **Step 3: Add a pinned CI installation and formatting gate**

In the existing Ubuntu `lua-syntax` job, install an explicit StyLua release
before running its check. Use Cargo's locked dependency resolution:

```yaml
- name: Install StyLua
  run: cargo install stylua --version 2.3.1 --locked
- name: Check Neovim Lua formatting
  run: stylua --check config/nvim
```

Keep the existing `luac5.3 -p` validation as a separate following step. The
version is intentional; any StyLua upgrade must be reviewed with its formatting
diff.

- [ ] **Step 4: Verify the gate exactly as CI does**

```bash
stylua --version
stylua --check config/nvim
find config/nvim -name '*.lua' -print0 | xargs -0 -n1 luac -p
```

Expected: all commands exit 0. On systems where `luac` is not 5.3, use the CI
equivalent `luac5.3 -p` command instead.

## Task 5: Whole-branch verification and authorized handoff preparation

**Files:**

- Modify only after commit authority: `docs/REVIEW-2026-07-14.md`

**Interfaces:**

- Consumes: all tests from Tasks 1–4 and the user's no-commit constraint.
- Produces: evidence for every addressed review item and a clean description of
the logical commits that may be created later.

- [ ] **Step 1: Run every repository-local verification gate**

```bash
find config/nvim -name '*.lua' -print0 | xargs -0 -n1 luac -p
stylua --check config/nvim
make test
state_dir="$(mktemp -d)"
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh --restore
NVIM_BIN="$(command -v nvim)" NVIM_SMOKE_STATE="$state_dir" \
  tests/test-nvim-smoke.sh
git diff --check
```

Expected: every command exits 0. The smoke test must be run from fresh,
temporary XDG directories, not through the user's linked `~/.config/nvim`.

- [ ] **Step 2: Perform a whole-branch review against the spec**

Check each design requirement explicitly:

```text
[ ] lazy-lock.json tracked and manager revision immutable
[ ] restore/update/Mason/provider policy documented
[ ] offline macOS+Ubuntu CI smoke cache keyed by lockfile
[ ] NVIM-03 adapter module names proven by actual adapter requires
[ ] NVIM-04 Docker spec uses Docker/Compose, no Caddy/Go residue
[ ] NVIM-05 uses native settings/before_init and no legacy flags
[ ] NVIM-07 path and provider instructions agree
[ ] StyLua tree and CI gate clean
[ ] make test still green
```

Also check `git status --short` and preserve the pre-existing untracked
`nvim.log` and unrelated Zsh modification untouched.

- [ ] **Step 3: Prepare, but do not create, the requested logical commits**

With no commit authority, leave changes uncommitted. Record the prospective
boundaries in the handoff:

```text
1. nvim: lock plugins and add offline smoke coverage
2. nvim: correct dormant language and provider configuration
3. style(nvim): apply StyLua formatting
4. ci: enforce StyLua formatting
5. docs: document Neovim recovery and update policy
```

Only after the user authorizes commits, create those commits, insert their real
hashes into `docs/REVIEW-2026-07-14.md`, and mark NVIM-01, NVIM-02, NVIM-03,
NVIM-04, NVIM-05, NVIM-07, NVIM-09, NVIM-11, TEST-01, and TEST-02 as resolved
in the report's existing format.
