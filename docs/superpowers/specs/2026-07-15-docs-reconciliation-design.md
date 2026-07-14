# Documentation reconciliation — design

- Date: 2026-07-15
- Branch: `docs-reconciliation` (from `neovim-reproducibility-phase-3` HEAD)
- Source review: `docs/REVIEW-2026-07-14.md`
- Scope: DOC-01, DOC-03, DOC-04, DOC-05, DOC-06, HOOK-01, GIT-05
  (DOC-02 / PACKAGE-01 already resolved before this task)

## Goal

Make `README.md` and the onboarding paths (plus `CLAUDE.md`) honest: every
claim must match what the code does today. Where docs are broader than the
code, fix the docs to the code — never write an unverified claim.

## Verified ground truth (checked against source, 2026-07-15)

- **Package tiers exist** — `install/packages.toml` + `install/packages.sh`,
  `--install-packages` / `--packages`. DOC-02 / PACKAGE-01 already Resolved
  (`20a7b79`, `d9b4016`). README already documents them. No package-tier work
  in this task.
- **macOS mutation categories** (`install/install-macos.sh`,
  `config/macos/defaults.zsh`):
  - `--apply-macos-defaults` (macOS only) calls `request_sudo`, runs
    `defaults.zsh`; on macOS 14+ it appends a Touch ID entry to
    `/etc/pam.d/sudo_local` (PAM). Skipped on < 14 or when the template is
    absent.
  - `--harden` (macOS only) calls `request_sudo`, runs `harden.zsh`.
  - `--install-packages` installs OS packages (tier-based).
  - Global broken-link sweep is `dotfiles clean --all`; ordinary sync/clean
    only touches manifest-owned links.
- **Neovim** (`config/nvim/lua/kostevski/config/languages.lua`,
  `config/nvim/lua/kostevski/plugins/ai.lua`):
  - Enabled languages: `{ "lua", "terraform", "cpp" }` (overridable via
    `DOTFILES_NVIM_SMOKE_LANGUAGES` / `enabled`). NOT Go/Python/Rust.
  - AI plugins: only `greggh/claude-code.nvim`. NOT Copilot/Aider.
  - 0.11.0 floor documented + enforced (NVIM-10 Resolved). Python provider
    path reconciled (NVIM-07 Resolved). Lockfile now tracked
    (`config/nvim/lazy-lock.json`, NVIM-01 Resolved).
- **Hooks** (`.githooks/setup.sh`) require `git config core.hooksPath
  .githooks`; `post-checkout` / `post-merge` run a profile-aware
  `dotfiles sync`. Not documented in README.
- **Machine-local git** (`config/git/config` include `gitconfig.local`;
  `config/git/gitconfig.local.example` is tracked; `*.local` not linked).
  Destination is `~/.config/git/gitconfig.local`. Not documented in README.
- **`.gitignore`** ignores `CLAUDE.md` and `docs/plans/`. `docs/plans/` has
  nothing tracked; the real plans live in tracked `docs/superpowers/plans/`.
  Project `CLAUDE.md` exists (199 lines) but is stale (says "three profiles",
  `--skip-install`, `make install-standard`, reinstall-on-update).
- **`docs/REVIEW-BACKLOG.md`** already carries a "Historical document" header
  but its body still lists resolved items as unchecked `[ ]`.

## Changes

### 1. DOC-01 — honest mutation enumeration (`README.md`)

Quick start is already link-first. Add a short "What the opt-in flags change"
block after Quick Start enumerating each mutation category behind its flag:
`--install-packages`, `--apply-macos-defaults` (sudo + Touch ID PAM on 14+),
`--harden` (sudo), and `dotfiles clean --all` (global sweep vs owned-only).
Tighten the "Safe linking by default" feature bullet to point at it.

### 2. DOC-03 — Neovim claims (`README.md`)

- Features "Language support: Go, Python, Rust..." → enabled-by-default
  Lua / Terraform / C++, more available via `languages.lua` `enabled`.
- Config-details "Full LSP support for multiple languages" → same honest
  framing.
- "AI integration (Copilot, Aider)" → "AI integration via `claude-code.nvim`".

Resolves NVIM-06 and NVIM-08.

### 3. DOC-04 — update / repo-location (`README.md`)

`make update` = safe sync is already correct. Add a note that `DOTDIR` is
derived from the linked CLI's physical target (`~/.dotfiles` fallback), so the
clone path is not hardcoded, and cross-reference the hook section.
Troubleshooting already states cleanup is owned-only — leave.

### 4. HOOK-01 — hook activation (`README.md`)

New short "Enabling auto-sync hooks (optional)" section: `bash
.githooks/setup.sh` (sets `core.hooksPath .githooks`); post-checkout /
post-merge run a profile-aware `dotfiles sync`; disable via
`git config --unset core.hooksPath`.

### 5. GIT-05 — machine-local git onboarding (`README.md`)

Under Manual Steps: destination `~/.config/git/gitconfig.local`; initializer
`cp config/git/gitconfig.local.example ~/.config/git/gitconfig.local` then
edit. Non-secret.

### 6. DOC-05 — backlog (`docs/REVIEW-BACKLOG.md`)

Keep the historical header; mark the entries now resolved (check-off /
strike-through) so the body can't read as current work.

### 7. DOC-06 — track project instructions (`.gitignore`, `CLAUDE.md`)

Un-ignore `CLAUDE.md`; remove the stale `docs/plans/` ignore line; refresh
`CLAUDE.md`'s stale claims to match code (profiles minimal/standard/full/all,
link-only bootstrap, safe-sync update, package tiers); commit `CLAUDE.md`.
Keep `*.local`, `.serena/`, `*.claude/`, `.local/` ignored.

### 8. Review doc (`docs/REVIEW-2026-07-14.md`)

Mark DOC-01, DOC-03, DOC-04, DOC-05, DOC-06, HOOK-01, GIT-05, NVIM-06, NVIM-08
Resolved in the existing `Resolved: <date> by <commit>` style (commit filled
in at commit time).

## Non-goals

- No package-tier behavior or docs changes (DOC-02 done).
- No Neovim code changes (document current reality; NVIM-06/08 are doc-only).
- No new doc-consistency test; the review doc is the tracking mechanism.

## Verification

- `make test` stays green (docs-only change). Run before finishing.
- Manual read-through of README for internal consistency.
