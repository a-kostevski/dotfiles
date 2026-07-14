# Documentation Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `README.md`, `CLAUDE.md`, and the onboarding docs match what the code does today, and mark the addressed review entries Resolved.

**Architecture:** Targeted edits to existing docs. No code changes. Reality is verified in `docs/superpowers/specs/2026-07-15-docs-reconciliation-design.md`; do not restate a claim this plan does not already contain.

**Tech Stack:** Markdown, GNU Make (`make test`), git.

## Global Constraints

- Document reality, not aspiration. Every claim must match source verified in the spec.
- Enabled Neovim languages are exactly `lua`, `terraform`, `cpp`. AI plugin is exactly `claude-code.nvim`.
- Valid profiles are `minimal | standard | full | all` (no `custom`).
- `make test` must stay green.
- Do not commit `*.local`, `.serena/`, `.local/`, `*.claude/` — keep those ignored.
- Work only on branch `docs-reconciliation`. Do not push.
- Mark resolved review entries with `Resolved: 2026-07-15 by <commit>` matching existing style.

---

### Task 1: DOC-01 — honest mutation enumeration (README)

**Files:**
- Modify: `README.md` (Features bullet ~line 9; after Quick Start ~line 47)

- [ ] **Step 1:** Tighten the "Safe linking by default" feature bullet to reference the enumeration. Replace the bullet at README.md lines 9-10 with:

```markdown
- **Safe linking by default**: A plain `./bootstrap.sh` only symlinks configs
  (existing files are backed up). Every system-mutating action is a separate
  opt-in flag — see [What the opt-in flags change](#what-the-opt-in-flags-change)
```

- [ ] **Step 2:** Add a new section immediately after the Quick Start code block (after current line 47, before `## Installation Profiles`):

```markdown
## What the opt-in flags change

A plain `./bootstrap.sh` is link-only: it creates symlinks and backs up any
files it would overwrite. Nothing else is touched unless you pass one of these:

- `--install-packages` — installs OS packages for the selected tier
  (see [Package Installation](#package-installation)).
- `--apply-macos-defaults` *(macOS only)* — **prompts for sudo**, writes system
  and UI preferences, and on macOS 14+ appends a Touch ID entry to
  `/etc/pam.d/sudo_local` (PAM). Skipped on older macOS or when the PAM
  template is absent.
- `--harden` *(macOS only)* — **prompts for sudo** and applies security
  hardening (`config/macos/harden.zsh`).
- `dotfiles clean --all` — removes **every** broken symlink under `~/.config`
  and `~/.local/bin`. Ordinary sync/clean only touch links this repo owns.
```

- [ ] **Step 3:** Verify no duplicate anchor / heading conflicts and the links resolve (headings `Package Installation` and `What the opt-in flags change` exist). Read the surrounding README region.

- [ ] **Step 4:** Commit.

```bash
git add README.md
git commit -m "docs: enumerate opt-in mutation categories (DOC-01)"
```

---

### Task 2: DOC-03 — correct Neovim claims (README)

**Files:**
- Modify: `README.md` (Features ~line 15; Neovim config-details ~lines 221,224)

- [ ] **Step 1:** Replace the Features "Language support" bullet (line 15):

```markdown
- **Language support**: LSP integration for many languages. Neovim enables
  Lua, Terraform, and C++ by default; enable more in
  `config/nvim/lua/kostevski/config/languages.lua`
```

- [ ] **Step 2:** In the `### Neovim` config-details list, replace "Full LSP support for multiple languages" with:

```markdown
- LSP support; languages enabled in `languages.lua` (Lua, Terraform, C++ by
  default) with more available on demand
```

- [ ] **Step 3:** Replace "AI integration (Copilot, Aider)" with:

```markdown
- AI integration via `claude-code.nvim`
```

- [ ] **Step 4:** Commit.

```bash
git add README.md
git commit -m "docs: correct Neovim language and AI plugin claims (DOC-03, NVIM-06, NVIM-08)"
```

---

### Task 3: DOC-04 + HOOK-01 — update, repo-location, hook activation (README)

**Files:**
- Modify: `README.md` (Updating section ~lines 306-316; new hooks section)

- [ ] **Step 1:** In the `## Updating` section, after the existing `dotfiles sync` paragraph, add a DOTDIR note:

```markdown
The repository location is not hardcoded: `DOTDIR` is derived from the physical
target of the linked `dotfiles` CLI, falling back to `~/.dotfiles`. Cloning
elsewhere works as long as you re-link from that location.
```

- [ ] **Step 2:** Add a new section (place it right after `## Updating`):

```markdown
## Enabling auto-sync hooks (optional)

Git hooks can re-sync your symlinks automatically after you pull or switch
branches. They are opt-in — a fresh clone does not enable them. To turn them on:

```bash
bash .githooks/setup.sh   # sets: git config core.hooksPath .githooks
```

- `post-merge` runs after `git pull`, `post-checkout` after switching branches.
- Both run `dotfiles sync` against your **stored profile**, so only that
  profile's links are reconciled.
- Disable at any time: `git config --unset core.hooksPath`.
```

- [ ] **Step 3:** Read the Troubleshooting "Broken Symlinks" block; confirm it already states cleanup is owned-only (it does). No change.

- [ ] **Step 4:** Commit.

```bash
git add README.md
git commit -m "docs: derived DOTDIR note and hook activation section (DOC-04, HOOK-01)"
```

---

### Task 4: GIT-05 — machine-local Git onboarding (README)

**Files:**
- Modify: `README.md` (Manual Steps section)

- [ ] **Step 1:** Add a subsection under `## Manual Steps` (after "Install Language-Specific Tools"):

```markdown
### Machine-local Git identity

Git identity and signing live in an untracked, machine-local file that the
main config includes. `*.local` files are intentionally not symlinked, so
create it once per machine:

```bash
cp config/git/gitconfig.local.example ~/.config/git/gitconfig.local
# then edit it and set [user] name / email (and optional signing)
```

The example documents optional delta-pager and SSH-signing blocks. Nothing in
`gitconfig.local` is committed.
```

- [ ] **Step 2:** Commit.

```bash
git add README.md
git commit -m "docs: document machine-local git onboarding (GIT-05)"
```

---

### Task 5: DOC-06 — track and refresh CLAUDE.md (.gitignore, CLAUDE.md)

**Files:**
- Modify: `.gitignore` (remove `CLAUDE.md` and `docs/plans/` lines)
- Modify: `CLAUDE.md` (correct stale claims)

- [ ] **Step 1:** In `.gitignore`, delete the `CLAUDE.md` line and the `docs/plans/` line. Keep `.local/`, `*.claude/`, `.serena/`, `.prompts`, `*.local`, `Brewfile*.lock.json`, `.DS_Store`.

- [ ] **Step 2:** Confirm `docs/plans/` has nothing worth keeping ignored: `git status --porcelain docs/plans/` and `ls docs/plans/`. If it holds only local scratch, leave the directory alone (it is simply no longer ignored); if it is empty/absent, nothing to do.

- [ ] **Step 3:** Read `CLAUDE.md` fully. Correct every stale claim to match code:
  - "three installation profiles (minimal, standard, full)" → "four link profiles (minimal, standard, full, all)".
  - Installation/Updates command block: plain `./bootstrap.sh` is link-only; packages via `--install-packages` (tier via `--packages`); `make update` = fast-forward pull then `dotfiles sync` (not reinstall). Remove/replace `--skip-install` and `make install-standard` if they no longer exist — verify against `bootstrap.sh --help` and `Makefile` before writing.
  - Symlink-management block: keep `dotfiles sync/status/clean`; note `dotfiles clean` is owned-only and `dotfiles clean --all` is the global sweep.
  - Any manifest reference points at `install/manifest.toml` + `install/manifest.sh` as the single source of truth.

- [ ] **Step 4:** Verify `CLAUDE.md` is now trackable and no longer ignored: `git check-ignore CLAUDE.md` should print nothing.

- [ ] **Step 5:** Commit.

```bash
git add .gitignore CLAUDE.md
git commit -m "docs: track and refresh project CLAUDE.md; drop stale docs/plans ignore (DOC-06)"
```

---

### Task 6: DOC-05 — mark resolved entries in the backlog

**Files:**
- Modify: `docs/REVIEW-BACKLOG.md`

- [ ] **Step 1:** Read `docs/REVIEW-BACKLOG.md` fully. For each unchecked `- [ ]` entry whose finding is resolved per `docs/REVIEW-2026-07-14.md` (e.g. Ubuntu Neovim too old → UBUNTU-01/UBUNTU-02 Resolved; clang-format file/dir → MAP-01 Resolved; custom-profile items → PROFILE-04 Resolved), change `- [ ]` to `- [x]` and append ` — superseded, see <ID> in REVIEW-2026-07-14.md`. Leave genuinely-open items unchecked. Keep the existing historical header.

- [ ] **Step 2:** Commit.

```bash
git add docs/REVIEW-BACKLOG.md
git commit -m "docs: mark superseded backlog entries resolved (DOC-05)"
```

---

### Task 7: Mark review entries Resolved + verify

**Files:**
- Modify: `docs/REVIEW-2026-07-14.md` (DOC-01, DOC-03, DOC-04, DOC-05, DOC-06, HOOK-01, GIT-05, NVIM-06, NVIM-08)

- [ ] **Step 1:** For each of DOC-01, DOC-03, DOC-04, DOC-05, DOC-06, HOOK-01, GIT-05, NVIM-06, NVIM-08: append ` — Resolved` to the heading and add a resolution line in existing style, e.g.:

```markdown
- Resolved: 2026-07-15 by `<commit>` (documented in README / CLAUDE.md)
```

Use the actual fixing commit hash(es) from this branch. NVIM-06/08 note "doc-only: enabled-vs-available documented in README".

- [ ] **Step 2:** Run the test suite.

Run: `cd <repo> && make test`
Expected: exits 0 (green). Docs-only changes must not affect it.

- [ ] **Step 3:** Read the full README top-to-bottom once for internal consistency (anchors resolve, no contradictory profile/language claims, no leftover `custom`/`Copilot`/`Aider`/`Go, Python, Rust`).

- [ ] **Step 4:** Commit.

```bash
git add docs/REVIEW-2026-07-14.md
git commit -m "docs: mark DOC-01/03/04/05/06, HOOK-01, GIT-05, NVIM-06/08 resolved"
```

---

## Self-review notes

- Spec coverage: DOC-01→T1, DOC-03→T2, DOC-04→T3, HOOK-01→T3, GIT-05→T4, DOC-06→T5, DOC-05→T6, review-doc resolutions + verification→T7. All spec sections covered.
- The commit hash in T7 Step 1 is filled from the actual commits produced by T1–T6 (may reference multiple commits).
- No package-tier or Neovim code changes (non-goals).
