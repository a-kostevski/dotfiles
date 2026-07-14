# Git hygiene set — design

Date: 2026-07-14
Source: [REVIEW-2026-07-14.md](../../REVIEW-2026-07-14.md), findings `GIT-01`
through `GIT-04`.

## Goal

Resolve the four outstanding Git findings from the 2026-07-14 review. They are
independent, low-risk correctness fixes with no shared state:

- `GIT-01` — the global excludes file hides legitimate project content.
- `GIT-02` — a concatenated Windows/macOS metadata pattern matches nothing.
- `GIT-03` — `git-lfs` is a globally `required` filter but installed nowhere.
- `GIT-04` — `git dm` can delete protected local branches.

## Non-goals

- No CI or test-gate changes. The review lists no automated gate for these, and
  correctness is verifiable by inspection plus a `git check-ignore` spot check.
- No README changes. None of these behaviors are documented there.
- No broader Git config refactor. Stay scoped to the four findings.

## Changes

### GIT-01 + GIT-02 — Minimal global gitignore

`config/git/ignore` is the value of Git's `core.excludesFile` (via
`$XDG_CONFIG_HOME/git/ignore`) and therefore applies to **every** repository on
the machine. It must contain only machine/OS/editor/tool-generated artifacts
that no project should ever track. Everything language-, build-, or
artifact-specific moves to per-project `.gitignore`.

The `GIT-02` typo `Thumbs.db.DS_Store` (two concatenated patterns matching
neither) is removed and replaced by a correct `Thumbs.db`.

New full contents of `config/git/ignore`:

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

Removed patterns and their new home (per-project `.gitignore`):

| Removed | Reason |
|---|---|
| `*.com` `*.class` `*.dll` `*.exe` `*.o` `*.so` | Compiled objects / vendored libs are project-specific and sometimes committed |
| `*.7z` `*.dmg` `*.gz` `*.iso` `*.jar` `*.rar` `*.tar` `*.zip` | Archives and vendored artifacts are legitimately committed by some projects |
| `*.log` `*.sql` `*.sqlite` | Migrations, fixtures, and sample data are commonly committed |
| `.Rhistory` `.RData` | R-session state is language-specific |
| `.vscode/` `.vs/` | Editor/IDE settings are a per-project decision (teams often commit `.vscode/`) |

### GIT-03 — Provision git-lfs on every platform

`config/git/config` declares an LFS filter with `required = true`
(`config/git/config:166-170`). With the filter required but the `git-lfs`
binary absent, any repository containing LFS pointers fails to check out or
commit. The chosen resolution is to make the promise true by installing the
binary everywhere; the tracked config already declares the per-user filter, so
no additional `git lfs install` step is required.

- `config/homebrew/Brewfile-min`: add `brew "git-lfs"` in the essential
  command-line tools block (near `brew "git"`).
- `config/homebrew/Brewfile-all`: add `brew "git-lfs"` (near `brew "git"` on
  line 16). Both files are added because the profiles select one Brewfile each
  rather than layering.
- `install/install-ubuntu.sh`: add `git-lfs` to the `packages` array (the apt
  package name is `git-lfs`).

The `[filter "lfs"]` block in `config/git/config` is left unchanged.

### GIT-04 — Branch-safe `git dm`

Current alias (`config/git/config:58-60`):

```gitconfig
dm = "!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d"
```

Problems: it only skips the current branch, so run from a feature branch it can
delete local `main`/`master`/`develop`; and it calls `xargs` on an empty set,
whose behavior differs by platform.

Replacement — a POSIX function that filters the current/worktree branch with
`grep`, excludes protected names by exact match with `case`, and iterates with
`while read` so an empty set is a no-op:

```gitconfig
dm = "!f() { git branch --merged | grep -vE '^[*+]' | while read -r b; do case \"$b\" in main|master|develop) ;; *) git branch -d \"$b\" ;; esac; done; }; f"
```

- `grep -vE '^[*+]'` drops the current branch (`*`) and worktree-held branches
  (`+`).
- Default `read` word-splitting trims the leading indentation from
  `git branch` output, so `$b` is the bare branch name.
- `case` matches protected names exactly, so `feature/main-x` is **not**
  excluded.
- `git branch -d` (safe delete) still refuses to remove unmerged branches.

## Verification

- `git check-ignore -v <path>` spot checks: a `schema.sql` and a `data.sqlite`
  in a scratch repo are **not** ignored after the change; a `.DS_Store` still is.
- `git config --file config/git/config --list` parses without error after the
  alias rewrite.
- `git dm` from a feature branch in a scratch repo with a merged throwaway
  branch deletes only the throwaway and leaves `main` intact; running it again
  with nothing to delete exits cleanly.
- Brewfile and Ubuntu edits are covered by existing package-installation review;
  confirm `git-lfs` appears once in each target file.
