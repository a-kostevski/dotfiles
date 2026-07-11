#!/usr/bin/env bash
# Regression tests for the uninstall machinery.
# Run via `make test` or directly: bash tests/test-uninstall.sh

set -uo pipefail

# Physical root (pwd -P): bootstrap.sh records physical link targets, and the
# fixed `dotfiles` resolves its own root the same way, so the sandbox must too.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"

echo "== find_owned_symlinks =="
tmp_scan="$(mktemp -d)"
mkdir -p "$tmp_scan/owner/config/nvim" "$tmp_scan/home/.config/nvim/lua"
echo "src" >"$tmp_scan/owner/config/nvim/init.lua"
echo "deep" >"$tmp_scan/owner/config/nvim/deep.lua"
ln -s "$tmp_scan/owner/config/nvim/init.lua" "$tmp_scan/home/.config/nvim/init.lua"
ln -s "$tmp_scan/owner/config/nvim/deep.lua" "$tmp_scan/home/.config/nvim/lua/deep.lua"
ln -s "/somewhere/else" "$tmp_scan/home/.config/foreign"
echo "real file" >"$tmp_scan/home/.config/realfile"

scan_out="$(find_owned_symlinks "$tmp_scan/home/.config" "$tmp_scan/owner" | sort)"
assert_eq "finds owned links at any depth, skips foreign links and files" \
  "$(printf '%s\n%s' \
    "$tmp_scan/home/.config/nvim/init.lua" \
    "$tmp_scan/home/.config/nvim/lua/deep.lua")" \
  "$scan_out"

assert_eq "missing dir yields empty output and rc 0" \
  "0|" \
  "$(out=$(find_owned_symlinks "$tmp_scan/nope" "$tmp_scan/owner"); echo "$?|$out")"

# Prefix must match on a path boundary: /owner-evil is not under /owner
ln -s "$tmp_scan/owner-evil-target" "$tmp_scan/home/.config/evil" 2>/dev/null || true
mkdir -p "$tmp_scan/owner-evil-target" 2>/dev/null || true
assert_eq "sibling dir sharing the owner prefix is not owned" \
  "" \
  "$(find_owned_symlinks "$tmp_scan/home/.config" "$tmp_scan/owner" | grep evil || true)"

echo "== is_owned_symlink =="
assert_eq "owned link -> 0" "0" \
  "$(is_owned_symlink "$tmp_scan/home/.config/nvim/init.lua" "$tmp_scan/owner"; echo $?)"
assert_eq "foreign link -> 1" "1" \
  "$(is_owned_symlink "$tmp_scan/home/.config/foreign" "$tmp_scan/owner"; echo $?)"
assert_eq "real file -> 1" "1" \
  "$(is_owned_symlink "$tmp_scan/home/.config/realfile" "$tmp_scan/owner"; echo $?)"
rm -rf "$tmp_scan"

echo "== newest_backup_path / restore_newest_backup =="
tmp_bak="$(mktemp -d)"
echo "oldest" >"$tmp_bak/cfg.backup.20240101_000000"
echo "newest" >"$tmp_bak/cfg.backup.20250101_000000"
echo "collision" >"$tmp_bak/cfg.backup.20240101_000000.1"
# mtime decides, not the name: make the lexically-oldest file the newest
touch "$tmp_bak/cfg.backup.20240101_000000.1"
sleep 1 2>/dev/null || true
touch "$tmp_bak/cfg.backup.20240101_000000"

assert_eq "newest_backup_path picks by mtime" \
  "$tmp_bak/cfg.backup.20240101_000000" \
  "$(newest_backup_path "$tmp_bak/cfg")"

assert_eq "no backups -> rc 1, empty output" "1|" \
  "$(out=$(newest_backup_path "$tmp_bak/other"); echo "$?|$out")"

restore_newest_backup "$tmp_bak/cfg" >/dev/null
assert_eq "restore moves newest backup into place" \
  "oldest" "$(cat "$tmp_bak/cfg" 2>/dev/null || echo MISSING)"
assert_eq "older backups are left alone" \
  "yes" "$([[ -f "$tmp_bak/cfg.backup.20250101_000000" ]] && echo yes || echo no)"

# Refuses to overwrite: cfg now exists, another backup remains
restore_out="$(restore_newest_backup "$tmp_bak/cfg" 2>&1)"
restore_rc=$?
assert_eq "restore refuses to overwrite existing dest" "1" "$restore_rc"
assert_contains "restore warns when dest exists" "already exists" "$restore_out"
assert_eq "dest untouched by refused restore" "oldest" "$(cat "$tmp_bak/cfg")"
rm -rf "$tmp_bak"

# mv failure must fail loudly (skip as root: root ignores mode bits)
if [[ $EUID -ne 0 ]]; then
  tmp_ro="$(mktemp -d)"
  echo "content" >"$tmp_ro/cfg.backup.20240101_000000"
  chmod 555 "$tmp_ro"
  ro_out="$(restore_newest_backup "$tmp_ro/cfg" 2>&1)"
  ro_rc=$?
  assert_eq "restore returns rc 1 when mv fails" "1" "$ro_rc"
  assert_contains "restore reports mv failure" "Failed to restore" "$ro_out"
  assert_eq "backup still exists after failed restore" \
    "yes" "$([[ -f "$tmp_ro/cfg.backup.20240101_000000" ]] && echo yes || echo no)"
  chmod 755 "$tmp_ro"
  rm -rf "$tmp_ro"
fi

echo "== manifest hygiene =="
tmp_man="$(mktemp -d)"
(
  # shellcheck disable=SC2030  # subshell scoping is deliberate
  MANIFEST_FILE="$tmp_man/manifest"
  update_manifest "/src/a" "/dest/a"
  update_manifest "/src/b" "/dest/b"
  update_manifest "/src/a2" "/dest/a"   # same dest again -> replaces, not appends
)
assert_eq "update_manifest dedups by dest" "2" \
  "$(wc -l <"$tmp_man/manifest" | tr -d ' ')"
assert_contains "latest src wins for duplicated dest" "|/src/a2|/dest/a" \
  "$(cat "$tmp_man/manifest")"
assert_eq "a dest similar to another is not clobbered" "1" \
  "$(grep -c "|/dest/b$" "$tmp_man/manifest")"

(
  # shellcheck disable=SC2030,SC2031
  MANIFEST_FILE="$tmp_man/manifest"
  remove_manifest_entries "/dest/a"
)
assert_eq "remove_manifest_entries drops only the named dest" \
  "1" "$(wc -l <"$tmp_man/manifest" | tr -d ' ')"
assert_contains "surviving entry is the other dest" "|/dest/b" \
  "$(cat "$tmp_man/manifest")"

(
  # shellcheck disable=SC2030,SC2031,SC2034
  MANIFEST_FILE="$tmp_man/missing-manifest"
  remove_manifest_entries "/dest/a"
)
assert_eq "remove on missing manifest is rc 0" "0" "$?"

assert_eq "read_manifest is gone" "1" \
  "$(type read_manifest >/dev/null 2>&1; echo $?)"
rm -rf "$tmp_man"

echo "== uninstall_symlink =="
tmp_un="$(mktemp -d)"
echo "src" >"$tmp_un/src"
ln -s "$tmp_un/src" "$tmp_un/link"
echo "original" >"$tmp_un/link.backup.20250101_000000"
echo "keep me" >"$tmp_un/notalink"

UNINSTALL_RESTORED=0
RESTORE=true DRY_RUN="" uninstall_symlink "$tmp_un/link" >/dev/null
assert_eq "removes the link and restores backup" \
  "original" "$(cat "$tmp_un/link" 2>/dev/null || echo MISSING)"
assert_eq "restore counter incremented" "1" "$UNINSTALL_RESTORED"
assert_eq "restored dest is a regular file, not a link" \
  "no" "$([[ -L "$tmp_un/link" ]] && echo yes || echo no)"

assert_eq "non-symlink dest -> rc 1, untouched" "1" \
  "$(RESTORE=true DRY_RUN="" uninstall_symlink "$tmp_un/notalink" >/dev/null; echo $?)"
assert_eq "real file survives" "keep me" "$(cat "$tmp_un/notalink")"

# --no-restore path: link removed, backup stays put
ln -s "$tmp_un/src" "$tmp_un/link2"
echo "bak2" >"$tmp_un/link2.backup.20250101_000000"
UNINSTALL_RESTORED=0
RESTORE=false DRY_RUN="" uninstall_symlink "$tmp_un/link2" >/dev/null
assert_eq "no-restore removes link" \
  "no" "$([[ -e "$tmp_un/link2" || -L "$tmp_un/link2" ]] && echo yes || echo no)"
assert_eq "no-restore leaves backup in place" \
  "yes" "$([[ -f "$tmp_un/link2.backup.20250101_000000" ]] && echo yes || echo no)"
assert_eq "no-restore does not bump counter" "0" "$UNINSTALL_RESTORED"

# Dry run: nothing changes, planned actions are printed
ln -s "$tmp_un/src" "$tmp_un/link3"
echo "bak3" >"$tmp_un/link3.backup.20250101_000000"
UNINSTALL_RESTORED=0
dry_out="$(RESTORE=true DRY_RUN="dry_run" uninstall_symlink "$tmp_un/link3")"
assert_contains "dry run announces rm" "[DRY-RUN] rm $tmp_un/link3" "$dry_out"
assert_contains "dry run announces restore" "[DRY-RUN] mv $tmp_un/link3.backup.20250101_000000" "$dry_out"
assert_eq "dry run leaves the link" \
  "yes" "$([[ -L "$tmp_un/link3" ]] && echo yes || echo no)"

# rm failure must fail loudly, not report a phantom removal (skip as root:
# root ignores the read-only parent's mode bits, so rm would still succeed)
if [[ $EUID -ne 0 ]]; then
  tmp_rorm="$(mktemp -d)"
  echo "src" >"$tmp_rorm/src"
  ln -s "$tmp_rorm/src" "$tmp_rorm/rmlink"
  chmod 555 "$tmp_rorm"   # read-only parent -> rm of the link inside fails
  UNINSTALL_RESTORED=0
  rorm_out="$(RESTORE=false DRY_RUN="" uninstall_symlink "$tmp_rorm/rmlink" 2>&1)"
  rorm_rc=$?
  assert_eq "uninstall_symlink returns rc 1 when rm fails" "1" "$rorm_rc"
  assert_contains "reports the rm failure" "Failed to remove" "$rorm_out"
  assert_eq "does not print a phantom Removed on failure" \
    "no" "$([[ "$rorm_out" == *"Removed:"* ]] && echo yes || echo no)"
  assert_eq "the link survives a failed rm" \
    "yes" "$([[ -L "$tmp_rorm/rmlink" ]] && echo yes || echo no)"
  chmod 755 "$tmp_rorm"
  rm -rf "$tmp_rorm"
fi

echo "== prune_empty_dirs =="
mkdir -p "$tmp_un/tree/a/b" "$tmp_un/tree/c"
echo "file" >"$tmp_un/tree/c/file"
DRY_RUN="" prune_empty_dirs "$tmp_un/tree"
assert_eq "empty subtree pruned" \
  "no" "$([[ -d "$tmp_un/tree/a" ]] && echo yes || echo no)"
assert_eq "non-empty dirs survive" \
  "yes" "$([[ -f "$tmp_un/tree/c/file" ]] && echo yes || echo no)"
mkdir -p "$tmp_un/empty-tree/x"
DRY_RUN="" prune_empty_dirs "$tmp_un/empty-tree"
assert_eq "fully-empty root is removed too" \
  "no" "$([[ -d "$tmp_un/empty-tree" ]] && echo yes || echo no)"
assert_eq "missing root is rc 0" "0" \
  "$(DRY_RUN="" prune_empty_dirs "$tmp_un/nope"; echo $?)"
rm -rf "$tmp_un"

echo "== dotfiles uninstall (end to end) =="
make_sandbox() {
  local home="$1"
  mkdir -p "$home/.config/nvim/lua" "$home/.config/tmux" "$home/.local/bin"
  # owned links into the real repo
  ln -s "$REPO_ROOT/config/nvim/init.lua" "$home/.config/nvim/init.lua"
  ln -s "$REPO_ROOT/config/tmux/tmux.conf" "$home/.config/tmux/tmux.conf"
  ln -s "$REPO_ROOT/config/zsh/zshenv" "$home/.zshenv"
  ln -s "$REPO_ROOT/bin/mkx" "$home/.local/bin/mkx"
  # a backup bootstrap would have made when it displaced a real nvim config
  echo "pre-dotfiles nvim" >"$home/.config/nvim/init.lua.backup.20250101_000000"
  # foreign link and real file that must survive any uninstall
  ln -s "/somewhere/else" "$home/.config/foreign"
  echo "hands off" >"$home/.config/realfile"
  # manifest with a stale duplicate, as real ones have
  {
    echo "2025-01-01 00:00:00|$REPO_ROOT/config/nvim/init.lua|$home/.config/nvim/init.lua"
    echo "2025-06-01 00:00:00|$REPO_ROOT/config/nvim/init.lua|$home/.config/nvim/init.lua"
    echo "2025-06-01 00:00:00|$REPO_ROOT/config/tmux/tmux.conf|$home/.config/tmux/tmux.conf"
  } >"$home/.config/.dotfiles-manifest"
  # stored profile marker, as a real install writes
  echo "standard" >"$home/.config/.dotfiles-profile"
}

# --- full uninstall ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
full_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --yes 2>&1)"
full_rc=$?
assert_eq "full uninstall exits 0" "0" "$full_rc"
assert_eq "nvim link replaced by restored backup" \
  "pre-dotfiles nvim" "$(cat "$tmp_e2e/.config/nvim/init.lua" 2>/dev/null || echo MISSING)"
assert_eq "tmux link gone and dir pruned" \
  "no" "$([[ -e "$tmp_e2e/.config/tmux" ]] && echo yes || echo no)"
assert_eq "zshenv home link gone" \
  "no" "$([[ -L "$tmp_e2e/.zshenv" ]] && echo yes || echo no)"
assert_eq "bin link gone" \
  "no" "$([[ -L "$tmp_e2e/.local/bin/mkx" ]] && echo yes || echo no)"
assert_eq ".local/bin itself survives" \
  "yes" "$([[ -d "$tmp_e2e/.local/bin" ]] && echo yes || echo no)"
assert_eq "foreign link survives" \
  "yes" "$([[ -L "$tmp_e2e/.config/foreign" ]] && echo yes || echo no)"
assert_eq "real file survives" \
  "hands off" "$(cat "$tmp_e2e/.config/realfile")"
assert_eq "manifest deleted" \
  "no" "$([[ -f "$tmp_e2e/.config/.dotfiles-manifest" ]] && echo yes || echo no)"
assert_eq "profile marker deleted on full uninstall" \
  "no" "$([[ -f "$tmp_e2e/.config/.dotfiles-profile" ]] && echo yes || echo no)"
assert_contains "summary reports removals" "Removed" "$full_out"
rm -rf "$tmp_e2e"

# --- full uninstall through a symlinked repo path (pwd vs pwd -P regression) ---
# When any component of the repo path is a symlink, `dotfiles` must resolve its
# own root physically (pwd -P) or ownership never matches the physical link
# targets bootstrap.sh wrote, and the uninstall silently no-ops.
tmp_sym="$(mktemp -d)"
alias_root="$tmp_sym/repo-alias"
ln -s "$REPO_ROOT" "$alias_root"          # a symlinked path to the same repo
sym_home="$tmp_sym/home"
mkdir -p "$sym_home/.config/nvim"
# link points at the PHYSICAL repo, exactly as bootstrap.sh (pwd -P) creates it
ln -s "$REPO_ROOT/config/nvim/init.lua" "$sym_home/.config/nvim/init.lua"
sym_out="$(HOME="$sym_home" "$alias_root/bin/dotfiles" uninstall --yes 2>&1)"
sym_rc=$?
assert_eq "uninstall via symlinked repo path exits 0" "0" "$sym_rc"
assert_eq "uninstall via symlinked repo path removes the link" \
  "no" "$([[ -L "$sym_home/.config/nvim/init.lua" ]] && echo yes || echo no)"
assert_contains "does not falsely report nothing to do" "Removed" "$sym_out"
rm -rf "$tmp_sym"

# --- confirmation gate ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall <<<"n" >/dev/null 2>&1
assert_eq "answering n aborts: links intact" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- per-config uninstall ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall nvim >/dev/null 2>&1
assert_eq "per-config: nvim backup restored" \
  "pre-dotfiles nvim" "$(cat "$tmp_e2e/.config/nvim/init.lua" 2>/dev/null || echo MISSING)"
assert_eq "per-config: tmux untouched" \
  "yes" "$([[ -L "$tmp_e2e/.config/tmux/tmux.conf" ]] && echo yes || echo no)"
assert_eq "per-config: zshenv untouched" \
  "yes" "$([[ -L "$tmp_e2e/.zshenv" ]] && echo yes || echo no)"
assert_eq "per-config: manifest pruned to surviving config" \
  "1" "$(wc -l <"$tmp_e2e/.config/.dotfiles-manifest" | tr -d ' ')"
assert_contains "per-config: surviving manifest entry is tmux" \
  "tmux.conf" "$(cat "$tmp_e2e/.config/.dotfiles-manifest")"
assert_eq "per-config: profile marker preserved" \
  "yes" "$([[ -f "$tmp_e2e/.config/.dotfiles-profile" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- pseudo-config bin ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall bin >/dev/null 2>&1
assert_eq "bin scope: mkx link gone" \
  "no" "$([[ -L "$tmp_e2e/.local/bin/mkx" ]] && echo yes || echo no)"
assert_eq "bin scope: configs untouched" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- dry run and no-restore ---
tmp_e2e="$(mktemp -d)"
make_sandbox "$tmp_e2e"
dry_e2e_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --dry-run 2>&1)"
assert_contains "dry run announces actions" "[DRY-RUN]" "$dry_e2e_out"
assert_eq "dry run changes nothing" \
  "yes" "$([[ -L "$tmp_e2e/.config/nvim/init.lua" && -f "$tmp_e2e/.config/.dotfiles-manifest" ]] && echo yes || echo no)"

HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall nvim --no-restore >/dev/null 2>&1
assert_eq "no-restore: link gone, no file restored" \
  "no" "$([[ -e "$tmp_e2e/.config/nvim/init.lua" ]] && echo yes || echo no)"
assert_eq "no-restore: backup still on disk" \
  "yes" "$([[ -f "$tmp_e2e/.config/nvim/init.lua.backup.20250101_000000" ]] && echo yes || echo no)"
rm -rf "$tmp_e2e"

# --- unknown config ---
tmp_e2e="$(mktemp -d)"
unknown_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall bogus 2>&1)"
unknown_rc=$?
assert_eq "unknown config is an error" "1" "$unknown_rc"
assert_contains "error names the offender" "bogus" "$unknown_out"
rm -rf "$tmp_e2e"

# --- nothing to do ---
tmp_e2e="$(mktemp -d)"
mkdir -p "$tmp_e2e/.config"
nothing_out="$(HOME="$tmp_e2e" "$REPO_ROOT/bin/dotfiles" uninstall --yes 2>&1)"
nothing_rc=$?
assert_eq "nothing to uninstall exits 0" "0" "$nothing_rc"
assert_contains "reports nothing to do" "Nothing to uninstall" "$nothing_out"
rm -rf "$tmp_e2e"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
