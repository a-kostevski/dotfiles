# Git Hygiene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve review findings `GIT-01`–`GIT-04`: a minimal global gitignore, git-lfs provisioning on every platform, and a branch-safe `git dm` alias.

**Architecture:** Four independent, low-risk config edits across three areas — `config/git/ignore`, `config/git/config`, and the two Homebrew Brewfiles plus the Ubuntu installer. No shared state between tasks; each is separately reviewable and committable. Verification is by inspection plus `git check-ignore` / `git config` spot checks, per the spec's non-goals (no CI or test-gate changes).

**Tech Stack:** Git config (gitconfig alias functions, `core.excludesFile`), Homebrew Brewfiles, apt package list in a Bash installer.

## Global Constraints

- Branch: work happens on `git-hygiene` (already checked out; design spec already committed there).
- No CI or test-gate changes. Verify by inspection and command spot checks.
- No README changes.
- No changes to the `[filter "lfs"]` block in `config/git/config` — it stays exactly as-is.
- Never modify `~/.config/` directly; only edit source files under the repo's `config/`.
- Homebrew formula name and apt package name are both `git-lfs`.
- Protected branch names for `git dm`: `main`, `master`, `develop`.

---

### Task 1: Minimal global gitignore (GIT-01 + GIT-02)

**Files:**
- Modify: `config/git/ignore` (full rewrite)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks. This file is Git's `core.excludesFile` and applies to every repo on the machine.

- [ ] **Step 1: Replace the file contents**

Overwrite `config/git/ignore` with exactly:

```gitignore
# OS-generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor backups and swap files
*~
.*~

# Personal tool state (never project content)
**/.claude/settings.local.json
```

This removes the `GIT-02` typo (`Thumbs.db.DS_Store` → `Thumbs.db`) and drops all language/build/artifact patterns (compiled objects, archives, `*.log`/`*.sql`/`*.sqlite`, `.Rhistory`/`.RData`, `.vscode/`, `.vs/`).

- [ ] **Step 2: Verify project content is no longer globally ignored**

Run:
```bash
tmp=$(mktemp -d) && git -C "$tmp" init -q \
  && git -C "$tmp" -c core.excludesFile="$PWD/config/git/ignore" check-ignore -v schema.sql data.sqlite build.jar .vscode/settings.json; \
  echo "exit=$?"; rm -rf "$tmp"
```
Expected: no `check-ignore` output lines and `exit=1` (none of those paths are ignored).

- [ ] **Step 3: Verify OS junk is still ignored**

Run:
```bash
tmp=$(mktemp -d) && git -C "$tmp" init -q \
  && git -C "$tmp" -c core.excludesFile="$PWD/config/git/ignore" check-ignore -v .DS_Store Thumbs.db; \
  rm -rf "$tmp"
```
Expected: two output lines showing `.DS_Store` and `Thumbs.db` matched by the excludes file.

- [ ] **Step 4: Commit**

```bash
git add config/git/ignore
git commit -m "git: trim global ignore to OS/editor junk (GIT-01, GIT-02)"
```

---

### Task 2: Provision git-lfs on every platform (GIT-03)

**Files:**
- Modify: `config/homebrew/Brewfile-min` (add `brew "git-lfs"` in the essential CLI tools block, near `brew "git"`)
- Modify: `config/homebrew/Brewfile-all` (add `brew "git-lfs"` near `brew "git"` on line 16)
- Modify: `install/install-ubuntu.sh` (add `git-lfs` to the `packages` array, near `git`)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks. Makes the already-tracked `[filter "lfs"] required = true` binary present on every platform.

- [ ] **Step 1: Add git-lfs to Brewfile-min**

In `config/homebrew/Brewfile-min`, add the line `brew "git-lfs"` immediately after `brew "git"` in the essential command-line tools block.

- [ ] **Step 2: Add git-lfs to Brewfile-all**

In `config/homebrew/Brewfile-all`, add the line `brew "git-lfs"` immediately after `brew "git"` (line 16).

- [ ] **Step 3: Add git-lfs to the Ubuntu package array**

In `install/install-ubuntu.sh`, add `git-lfs` to the `packages=(...)` array, on its own line immediately after `git`.

- [ ] **Step 4: Verify git-lfs appears once in each target**

Run:
```bash
grep -c 'git-lfs' config/homebrew/Brewfile-min config/homebrew/Brewfile-all install/install-ubuntu.sh
```
Expected: each file reports `1`.

- [ ] **Step 5: Verify the Brewfiles still parse (macOS only, optional)**

Run (only where Homebrew is available):
```bash
brew bundle list --file=config/homebrew/Brewfile-min >/dev/null && echo "min OK"
brew bundle list --file=config/homebrew/Brewfile-all >/dev/null && echo "all OK"
```
Expected: `min OK` and `all OK`. Skip on machines without Homebrew.

- [ ] **Step 6: Verify the Ubuntu installer still passes shellcheck**

Run:
```bash
shellcheck install/install-ubuntu.sh && echo "shellcheck OK"
```
Expected: `shellcheck OK` (no new warnings introduced by the one-line addition).

- [ ] **Step 7: Commit**

```bash
git add config/homebrew/Brewfile-min config/homebrew/Brewfile-all install/install-ubuntu.sh
git commit -m "git: install git-lfs on macOS and Ubuntu (GIT-03)"
```

---

### Task 3: Branch-safe `git dm` alias (GIT-04)

**Files:**
- Modify: `config/git/config:58-60` (the `dm` alias)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Replace the alias**

In `config/git/config`, keep the two comment lines (58–59) and replace the `dm = ...` line (60) with:

```gitconfig
	dm = "!f() { git branch --merged | grep -vE '^[*+]' | while read -r b; do case \"$b\" in main|master|develop) ;; *) git branch -d \"$b\" ;; esac; done; }; f"
```

(Leading indentation is a tab, matching the surrounding `[alias]` block.)

- [ ] **Step 2: Verify the config still parses**

Run:
```bash
git config --file config/git/config --get alias.dm && echo "parse OK"
```
Expected: prints the new alias body followed by `parse OK`.

- [ ] **Step 3: Verify protected branches survive and merged branches are deleted**

Run (isolated scratch repo, exercises the alias end-to-end):
```bash
tmp=$(mktemp -d); (
  cd "$tmp"
  git init -q; git config user.email t@t; git config user.name t
  git config alias.dm "!$(git config --file "$OLDPWD/config/git/config" --get alias.dm | sed 's/^!//')"
  git commit -q --allow-empty -m init            # branch: main
  git checkout -q -b throwaway; git commit -q --allow-empty -m work
  git checkout -q main; git merge -q throwaway    # throwaway now merged into main
  git checkout -q -b feature                      # run dm from a non-default branch
  git dm
  echo "--- remaining branches ---"; git branch
)
rm -rf "$tmp"
```
Expected: under `remaining branches`, `main` and `feature` are present and `throwaway` is gone. No `xargs`/empty-input error.

- [ ] **Step 4: Verify empty set is a clean no-op**

Run:
```bash
tmp=$(mktemp -d); (
  cd "$tmp"
  git init -q; git config user.email t@t; git config user.name t
  git config alias.dm "!$(git config --file "$OLDPWD/config/git/config" --get alias.dm | sed 's/^!//')"
  git commit -q --allow-empty -m init
  git dm; echo "exit=$?"
)
rm -rf "$tmp"
```
Expected: `exit=0` with no error output (nothing to delete).

- [ ] **Step 5: Commit**

```bash
git add config/git/config
git commit -m "git: make dm alias skip protected and current branches (GIT-04)"
```

---

## Notes for the implementer

- The scratch-repo verification in Task 3 copies the alias out of the tracked file so the check exercises the exact committed string, including escaping. If the `git config --get` round-trip is awkward in the runner, an acceptable substitute is to run the same branch setup and paste the alias body directly into a `git -c alias.dm='...'` invocation — the behavioral assertions (protected branches survive, merged branch deleted, empty set is a no-op) are what matter.
- Do not touch `[filter "lfs"]`; the required filter is intentional now that the binary is provisioned.
