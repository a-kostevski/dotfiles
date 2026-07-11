# Design: `dotfiles uninstall`

Date: 2026-07-10
Status: approved

## Problem

The symlink manifest (`~/.config/.dotfiles-manifest`) is written on every link
by `install/symlinks.sh` but never consumed. It grows unbounded with no dedup,
and `read_manifest` is dead code. There is no way to remove the dotfiles from a
machine or to cleanly retire a single tool's config. Backups created by
`create_symlink` (`<dest>.backup.<timestamp>[.N]`) are never restored.

## Command surface

- `dotfiles uninstall [config...]`, alias `u`.
  - No args: full uninstall of all repo-owned links. Requires an interactive
    confirmation prompt; `--yes`/`-y` skips it.
  - With config names: scoped to those configs. No prompt.
  - The pseudo-config name `bin` scopes to `~/.local/bin` links pointing into
    `$DOTFILES_ROOT/bin`. Nothing in `config/` is named `bin`, so there is no
    collision.
- Flags:
  - `--dry-run`/`-n`: print every action without changing anything.
  - `--no-restore`: remove links but do not restore backups.
  - `--verbose`/`-v`: detailed output.

## Discovery: filesystem scan

The filesystem is the source of truth, not the manifest. A symlink is "ours"
iff its `readlink` output lies under `$DOTFILES_ROOT/`.

- Full mode scans:
  - symlinks under `~/.config` at unbounded depth (links are created per-file
    at `$dest_base/<config>/<rel_path>`, which can be arbitrarily deep — the
    depth-2 limit in `get_synced_configs` is only valid for detection, not
    enumeration),
  - `~/.local/bin` at depth 1,
  - the special home links `~/.zshenv` and `~/.lldbinit`.
- Per-config mode scans `~/.config/<name>` for links into
  `$CONFIG_DIR/<name>`, plus the config's special home link where applicable
  (`zsh` → `~/.zshenv`, `lldb` → `~/.lldbinit`), and `bin` as described above.

This is robust against everything the manifest gets wrong: stale entries from
renamed configs, duplicate lines, and links that predate manifest writes.

## Removal and backup restore

For each owned link:

1. Remove the symlink (via the existing `dry_run` helper).
2. If restore is enabled and backups matching `<dest>.backup.*` exist, move
   the newest one (by mtime, since the `.N` collision suffix breaks lexical
   ordering) back to `<dest>`. Older backups are left in place and reported.
3. Restore never overwrites: if something already exists at `<dest>` after
   link removal (should not happen, but guard anyway), warn and skip.

Afterwards, prune now-empty directories under the affected
`~/.config/<name>` trees. Never remove `~/.config` itself or `~/.local/bin`.

## Manifest hygiene

- Full uninstall deletes `~/.config/.dotfiles-manifest`.
- Per-config uninstall rewrites the manifest without entries whose dest was
  removed, deduping by dest (last entry wins) as a side effect.
- `update_manifest` is fixed to dedup on write: rewrite the manifest without
  the dest being added, then append the new entry. This stops unbounded
  growth at the source.
- `read_manifest` (dead code) is deleted.

## Structure

- Core logic lives in `install/symlinks.sh` next to its siblings:
  - `find_owned_symlinks <dir> [max_depth]` — emit owned links under a dir.
  - `restore_newest_backup <dest>` — restore step 2 above.
  - `remove_manifest_entries <dest...>` / manifest rewrite helper.
  - `uninstall_symlink <dest>` — remove + restore, honoring `DRY_RUN` and
    `RESTORE` flags.
- `cmd_uninstall` in `bin/dotfiles` stays thin, mirroring `cmd_sync`: parse
  args, confirm if full mode, call library functions, print a summary
  (removed / restored / skipped counts).
- Help text (`usage`) and the command dispatch table gain the new command.

## Error handling

- Missing manifest is fine — the scan does not need it.
- A dest that is a real file or a foreign symlink is never touched.
- Exit non-zero only on real failures (e.g. `rm`/`mv` errors), not on
  "nothing to uninstall" — that prints a success message with zero counts.
- Unknown config names in per-config mode are an error naming the offender.

## Testing

Follow the existing bootstrap regression-test pattern (CI from `0bf9089`,
shellcheck gated at warning):

- Sandbox `$HOME` test: sync a config, plant a pre-existing file first so a
  backup is created, run `uninstall`, assert: links gone, backup restored,
  manifest deleted, empty dirs pruned.
- Per-config test: sync two configs, uninstall one, assert the other's links
  and manifest entries survive.
- Dry-run test: assert no filesystem changes.
- `--no-restore` test: link removed, backup left in place.
- `update_manifest` dedup unit test: repeated syncs yield one entry per dest.
- `make test` and shellcheck must pass.

## Out of scope

- Restoring from anything other than the newest backup (older backups are
  reported, not managed).
- Uninstalling OS packages installed by bootstrap.
- The other REVIEW-BACKLOG.md items (clang-format handling, custom profile,
  etc.).
