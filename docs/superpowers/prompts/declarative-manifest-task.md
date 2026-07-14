# Task handoff: declarative source manifest + profile cleanup

You are Claude Code working in a personal dotfiles repository at
`/Users/antonkostevski/dev/repos/github.com/a-kostevski/dotfiles` (macOS + Ubuntu,
Bash/Zsh, symlink-based config management). Read `CLAUDE.md` at the repo root and
`docs/REVIEW-2026-07-14.md` before doing anything — they are authoritative.

## Your task

Address the review's **Phase 1** "Unify lifecycle state" work that is still open,
centered on its highest-value recommendation: **introduce one declarative
source→destination→profile→platform manifest** and drive lifecycle operations
from it, then remove the now-dead profile surface.

Scope (all from `docs/REVIEW-2026-07-14.md`):

1. **Phase 1.1 — the declarative source manifest (the core of this task).**
   Replace the imperative, scattered mapping logic (see "Current architecture"
   below) with a single tracked, declarative source of truth that states, for
   each component: its source path under `config/` (or a top-level file), its
   destination, which profiles include it, and which platforms it applies to.
   Linking, status, clean, and uninstall should all derive their file set from
   this one manifest instead of re-deriving it four different ways.
2. **DEST-01 (Medium)** — `--config-dest`/`--bin-dest` are only honored by
   linking. The installed manifest, stored profile, `status`, `clean`,
   `uninstall`, and some directory creation still hardcode `$HOME`. Either
   thread the destination context through every operation, or remove the flags
   until full support exists. Decide with the user during brainstorming.
3. **PROFILE-04 (Low)** — the interactive/custom profile subsystem in
   `install/profiles.sh` (`select_profile`, `select_custom_components`,
   `select_profile_with_current`, `detect_current_profile`, `CUSTOM_CONFIGS`,
   ~180–250 lines) has no caller. `custom` validates but resolves to minimal
   behavior non-interactively. Wire up an explicit interactive command OR delete
   the subsystem and reject `custom`. Recommend deletion unless the user wants
   interactive selection.
4. **PROFILE-03 (Low)** — git hooks (`.githooks/post-checkout`,
   `.githooks/post-merge`) trigger sync only for paths under `config/`. Changes
   to `install/profiles.sh`, the new manifest, `bin/`, or bootstrap don't trigger
   a needed sync. Extend the change detection to a defined set of lifecycle
   inputs (the manifest especially).
5. **SCAFFOLD-01 (Low)** — delete the empty config trees `config/defaults/`,
   `config/security/`, `config/ubuntu/` unless a real config needs the namespace.

**Do NOT redo already-resolved work.** These Phase 1 items are already fixed
(see the review's "Resolved" tags) — confirm, don't reimplement: PROFILE-01
(stored profile authoritative for sync), PROFILE-02 (profile-aware hooks/watch),
STATUS-01 (profile-aware status + exit codes), CLEAN-01 (ownership-scoped
cleanup), VALIDATE-01 (make validate/clean delegate to the CLI). CLI-01 (unknown
command exit code) is separate and out of scope here.

## Critical distinction: two different "manifests"

This repo has, and the task adds, two separate things. Do not conflate them:

- **Installed manifest (already exists, works):** `~/.config/.dotfiles-manifest`,
  format `timestamp|src|dest`, written by `update_manifest()` in
  `install/symlinks.sh`. It is a *runtime record* of what is currently linked,
  consumed by `uninstall`/`clean` to know what this repo owns. Keep it (or evolve
  it), but it is NOT the declarative source of truth.
- **Source manifest (what Phase 1.1 asks you to create):** a *tracked,
  declarative* description in the repo that replaces the hardcoded
  `PROFILE_CONFIGS`, `PROFILE_OS_SPECIFIC`, the clang-format/curl special cases,
  and the per-component logic in `get_config_symlinks()`. This is the new
  artifact. Every lifecycle command computes its expected file set from it.

A likely clean design: the source manifest is the single declaration; linking
reads it to produce links AND writes the installed manifest as the runtime
record. Explore this with the user.

## Current architecture (grounding — verify before trusting)

- `bootstrap.sh` (490 lines): entry point. Parses flags incl. `CONFIG_DEST`
  (`~/.config`) and `BIN_DEST` (`~/.local/bin`); links configs and binaries.
- `bin/dotfiles` (558 lines): lifecycle CLI — `sync`, `clean`, `status`,
  `uninstall`, `profile`, watch mode. Stored profile at
  `~/.config/.dotfiles-profile` (`get_stored_profile`/`save_profile`).
- `install/profiles.sh` (437 lines): imperative profile definitions.
  `PROFILE_CONFIGS` (minimal/standard/full → component lists),
  `PROFILE_OS_SPECIFIC` (`macos_full`, `ubuntu_full`), `get_config_list`,
  `config_component_exists`, and the dead interactive subsystem (PROFILE-04).
- `install/symlinks.sh` (499 lines): `create_symlink`, `check_symlink`,
  `clean_broken_symlinks`, `is_owned_symlink`, `uninstall_symlink`,
  `update_manifest`/`remove_manifest_entries`, `get_config_symlinks` (maps a
  component to source|dest lines; special-cases the top-level clang-format/curl
  files), `check_symlink_health` (dead — no callers).
- `install/lib.sh` (195 lines): shared helpers, `detect_os` → `OS_TYPE`
  (`macos`/`ubuntu`/`unsupported`), `OS_VERSION`.
- `.githooks/`: `post-checkout`, `post-merge` (both route through
  `bin/dotfiles sync`), `setup.sh`.
- `Makefile` (207 lines): `install`, `sync`, `validate`, `clean`, `test`, etc.
- Tests: `make test` currently passes (87 across bootstrap/uninstall/zsh in
  `tests/`, sharing `tests/lib.sh`). This is your regression safety net.

## Constraints

- Follow `CLAUDE.md`: never edit `~/.config/` directly (edit `config/` sources
  then `dotfiles sync`); use Serena's symbolic tools for code where applicable;
  test Lua with `luac -p` (n/a here); lint shell with `shellcheck`.
- Preserve the strengths the review credits: per-file symlinking, collision-safe
  timestamped backups, physical-path ownership checks for uninstall, backup
  restoration. Do not regress these.
- Cross-platform: macOS and Ubuntu/Debian. Respect XDG paths.
- `make test` must stay green. Behavior changes need updated/added tests —
  extend `tests/` following the existing harness; several lifecycle interactions
  are under-tested (see TEST-03), so add coverage for
  manifest-driven link/status/clean/uninstall.
- Keep changes reviewable: the review favors small, well-bounded units. This is a
  large refactor — decompose it.
- Do not commit or push unless the user asks. Work on a feature branch, not
  `main`.

## Required workflow

This repo uses the "superpowers" skill workflow. Follow it:

1. **Brainstorm first** (`superpowers:brainstorming`). This task has real design
   decisions the user must weigh in on before any code — surface them one at a
   time. At minimum:
   - Manifest format: a static declarative file (which language — a `.tsv`/`.conf`
     table parsed in Bash? a here-doc data block? a small DSL?) vs. a generated
     one. Bash-parseable and diff-friendly matters; avoid adding a runtime
     dependency (no `jq`/`yq` unless the user accepts provisioning it).
   - How profile membership and platform gating are expressed per entry.
   - How top-level home files (clang-format→`~/.clang-format`,
     curl→`~/.curlrc`) fit the same schema.
   - DEST-01: full destination-threading vs. removing the flags.
   - PROFILE-04: delete vs. wire up interactive selection.
   - Migration/back-compat for the existing installed manifest and any
     already-linked machines.
2. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-declarative-manifest-design.md`,
   get user approval.
3. **Plan** (`superpowers:writing-plans`) → save under `docs/superpowers/plans/`.
4. **Execute** (`superpowers:subagent-driven-development`), task-by-task with
   reviews, then a final whole-branch review and
   `superpowers:finishing-a-development-branch`.

## Definition of done

- A single tracked declarative source manifest exists; `link`, `status`,
  `clean`, and `uninstall` all derive their file set from it (no more 4×
  re-derivation).
- DEST-01 resolved per the user's chosen direction.
- PROFILE-04 and SCAFFOLD-01 dead surface removed (or interactive selection
  deliberately wired up).
- PROFILE-03 hook change-detection covers the manifest and lifecycle inputs.
- `make test` green, with new tests covering the manifest-driven paths.
- README/docs updated where behavior or file layout changed (the review flags
  doc drift — DOC-04 — keep docs honest).
- The review doc's Phase 1 entries you addressed are marked Resolved with the
  commit that fixed them, matching the existing "Resolved: <date> by <commit>"
  style.
