#!/usr/bin/env bash
# Regression tests for the bootstrap/profile machinery.
# Run via `make test` or directly: bash tests/test-bootstrap.sh

set -uo pipefail

# pwd -P: bootstrap.sh links point at the physical repo path, so the sandbox
# must compare against the physical root (matches tests/test-uninstall.sh).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT" || exit 1

# shellcheck source=tests/lib.sh
source "$REPO_ROOT/tests/lib.sh"

echo "== get_config_list =="
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/profiles.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"

# Named profiles must emit one config per line (regression: a quoting bug
# once made every named profile emit a single space-joined line, which the
# symlink loop silently skipped — profiles installed nothing)
assert_eq "minimal emits one config per line" \
  "$(printf 'git\nzsh\ntmux')" \
  "$(get_config_list minimal)"

assert_eq "standard extends minimal" \
  "$(printf 'git\nzsh\ntmux\nnvim\nbat\npython\nripgrep')" \
  "$(get_config_list standard)"

full_macos="$(get_config_list full macos)"
assert_contains "full/macos includes base configs" "nvim" "$full_macos"
assert_contains "full/macos includes karabiner" "karabiner" "$full_macos"
assert_contains "full/macos includes kitty" "kitty" "$full_macos"

full_ubuntu="$(get_config_list full ubuntu)"
assert_eq "full/ubuntu has no macOS extras" "" "$(grep -E 'karabiner|kitty|homebrew' <<<"$full_ubuntu" || true)"

if get_config_list bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: unknown profile should return non-zero"
else
  PASS=$((PASS + 1))
  echo "  ok: unknown profile returns non-zero"
fi

# Every config named in a profile must exist as a directory in config/
echo "== profile configs exist =="
missing=""
for profile in minimal standard full; do
  while IFS= read -r cfg; do
    # clang-format is a single file, tracked as a known exception
    [[ "$cfg" == "clang-format" ]] && continue
    [[ -d "$REPO_ROOT/config/$cfg" ]] || missing="$missing $profile:$cfg"
  done < <(get_config_list "$profile" macos)
done
assert_eq "all profile configs exist in config/" "" "$missing"

echo "== bootstrap dry run =="
dry_out="$(./bootstrap.sh --profile minimal --dry-run 2>&1)"
assert_contains "dry run processes git" "Processing git configuration" "$dry_out"
assert_contains "dry run processes zsh" "Processing zsh configuration" "$dry_out"
assert_contains "dry run processes tmux" "Processing tmux configuration" "$dry_out"
assert_contains "default bootstrap is link-only" "No system provisioning requested" "$dry_out"
assert_eq "default bootstrap does not run provisioning" "" "$(grep -F 'Running requested system provisioning' <<<"$dry_out" || true)"
assert_eq "dry run emits no [DEBUG] noise" "" "$(grep -F '[DEBUG]' <<<"$dry_out" || true)"

echo "== cli entry behavior =="
# --help is a success and prints usage
help_out="$(./bootstrap.sh --help)"
help_rc=$?
assert_eq "--help exits 0" "0" "$help_rc"
assert_contains "--help prints usage" "Usage:" "$help_out"
assert_contains "--help documents package opt-in" "--install-packages" "$help_out"
assert_contains "--help documents defaults opt-in" "--apply-macos-defaults" "$help_out"
assert_contains "--help documents hardening opt-in" "--harden" "$help_out"

ubuntu_installer="$(<"$REPO_ROOT/install/install-ubuntu.sh")"
assert_contains "Ubuntu installer installs persistent tools with uv" \
  "tool install thefuck" "$ubuntu_installer"
assert_eq "Ubuntu installer no longer invokes pipx" "" \
  "$(grep -E '(^|[[:space:]])pipx[[:space:]]+install' <<<"$ubuntu_installer" || true)"

# an unknown flag must FAIL, not silently exit 0 (which would defeat set -e /
# || error handling in a calling script, Makefile, or CI job)
./bootstrap.sh --definitely-not-a-flag >/dev/null 2>&1
unknown_rc=$?
assert_eq "unknown flag exits non-zero (2)" "2" "$unknown_rc"
unknown_both="$(./bootstrap.sh --definitely-not-a-flag 2>&1 || true)"
assert_contains "unknown flag is reported" "Unknown option" "$unknown_both"

./bootstrap.sh --sync --install-packages >/dev/null 2>&1
provisioning_sync_rc=$?
assert_eq "sync rejects system provisioning" "2" "$provisioning_sync_rc"
provisioning_sync_out="$(./bootstrap.sh --sync --install-packages 2>&1 || true)"
assert_contains "sync provisioning error is clear" "--sync cannot be combined" "$provisioning_sync_out"

echo "== all profile exclusions =="
# `all` must only emit real user configs; installer/scaffolding dirs under
# config/ must never be linked into ~/.config
all_list="$(get_config_list all)"
for excluded in macos ubuntu defaults security; do
  assert_eq "all profile excludes $excluded" "" "$(grep -x "$excluded" <<<"$all_list" || true)"
done
assert_contains "all profile still includes real configs" "nvim" "$all_list"

echo "== bash version guard =="
# Stock macOS bash is 3.2; profiles.sh needs bash 4+ (declare -gA). The entry
# points must fail with a clear message instead of a parse error.
if [[ -x /bin/bash ]] && [[ "$(/bin/bash -c 'echo "${BASH_VERSINFO[0]}"')" -lt 4 ]]; then
  guard_out="$(/bin/bash "$REPO_ROOT/bootstrap.sh" --help 2>&1 || true)"
  assert_contains "bootstrap.sh rejects bash 3 clearly" "requires bash 4" "$guard_out"
  guard_out="$(/bin/bash "$REPO_ROOT/bin/dotfiles" --help 2>&1 || true)"
  assert_contains "bin/dotfiles rejects bash 3 clearly" "requires bash 4" "$guard_out"
else
  echo "  skip: system bash is >= 4, guard not exercisable"
fi

echo "== backup collisions =="
# Two backups of the same path in the same second must not overwrite each
# other. `date` is stubbed inside a subshell to force the collision.
tmp_backup="$(mktemp -d)"
(
  date() { echo "20260101_000000"; }
  # shellcheck disable=SC2034  # consumed by the sourced create_symlink
  MANIFEST_FILE="$tmp_backup/manifest"
  # shellcheck disable=SC2034
  DRY_RUN="" FORCE=false VERBOSE=false
  echo "real config" >"$tmp_backup/settings"
  echo "earlier backup" >"$tmp_backup/settings.backup.20260101_000000"
  echo "source" >"$tmp_backup/src"
  create_symlink "$tmp_backup/src" "$tmp_backup/settings" >/dev/null
)
assert_eq "existing same-second backup preserved" \
  "earlier backup" "$(cat "$tmp_backup/settings.backup.20260101_000000")"
assert_eq "displaced file backed up under a suffixed name" \
  "real config" "$(cat "$tmp_backup/settings.backup.20260101_000000.1" 2>/dev/null || echo MISSING)"
assert_eq "dest is linked to src" \
  "$tmp_backup/src" "$(readlink "$tmp_backup/settings")"
rm -rf "$tmp_backup"

echo "== clean_broken_symlinks =="
tmp_clean="$(mktemp -d)"
mkdir -p "$tmp_clean/.config"
ln -s "$tmp_clean/nonexistent" "$tmp_clean/.config/deadlink"
clean_dry_out="$(HOME="$tmp_clean" clean_broken_symlinks dry_run)"
assert_contains "dry clean reports the broken link" \
  "Would remove: $tmp_clean/.config/deadlink" "$clean_dry_out"
assert_contains "dry clean says would-remove, not found" \
  "Would remove 1 broken symlink" "$clean_dry_out"
assert_eq "dry clean leaves the link in place" \
  "yes" "$([[ -L "$tmp_clean/.config/deadlink" ]] && echo yes || echo no)"
clean_out="$(HOME="$tmp_clean" clean_broken_symlinks "")"
assert_contains "real clean reports removal count" \
  "Removed 1 broken symlink" "$clean_out"
assert_eq "real clean removes the link" \
  "no" "$([[ -L "$tmp_clean/.config/deadlink" ]] && echo yes || echo no)"
rm -rf "$tmp_clean"

echo "== sync mode dry run =="
# Safety net for set -u/pipefail: the full sync path must still run clean
tmp_sync="$(mktemp -d)"
sync_out="$(HOME="$tmp_sync" ./bootstrap.sh --sync --dry-run --profile minimal 2>&1)"
sync_rc=$?
assert_eq "sync dry run exits 0" "0" "$sync_rc"
assert_contains "sync dry run completes" "Sync completed successfully" "$sync_out"
rm -rf "$tmp_sync"

echo "== install + uninstall round trip (real, not dry-run) =="
# Covers the create/manifest/backup path (previously only dry-run tested) and
# chains into uninstall for a full round trip. A pre-existing real file must be
# backed up on install and restored on uninstall.
tmp_rt="$(mktemp -d)"
mkdir -p "$tmp_rt/.config/tmux"
echo "my old tmux" >"$tmp_rt/.config/tmux/tmux.conf"   # pre-existing real file
HOME="$tmp_rt" ./bootstrap.sh --sync --profile minimal >/dev/null 2>&1
install_rc=$?
assert_eq "real install exits 0" "0" "$install_rc"

# links are created and point into the repo
assert_eq "tmux.conf is a symlink into the repo" \
  "$REPO_ROOT/config/tmux/tmux.conf" "$(readlink "$tmp_rt/.config/tmux/tmux.conf" 2>/dev/null)"
assert_eq "zshenv is linked into the repo" \
  "$REPO_ROOT/config/zsh/zshenv" "$(readlink "$tmp_rt/.zshenv" 2>/dev/null)"
assert_eq "a bin script is linked into the repo" \
  "$REPO_ROOT/bin/mkx" "$(readlink "$tmp_rt/.local/bin/mkx" 2>/dev/null)"
assert_contains "manifest records the tmux link" \
  "$tmp_rt/.config/tmux/tmux.conf" "$(cat "$tmp_rt/.config/.dotfiles-manifest" 2>/dev/null)"

# the displaced real file was backed up, not destroyed
tmux_backup="$(find "$tmp_rt/.config/tmux" -name 'tmux.conf.backup.*' | head -1)"
assert_eq "displaced real tmux.conf was backed up" \
  "my old tmux" "$(cat "$tmux_backup" 2>/dev/null || echo MISSING)"

# re-installing must be idempotent: no new backups, links still valid
backups_before="$(find "$tmp_rt" -name '*.backup.*' | wc -l | tr -d ' ')"
HOME="$tmp_rt" ./bootstrap.sh --sync --profile minimal >/dev/null 2>&1
backups_after="$(find "$tmp_rt" -name '*.backup.*' | wc -l | tr -d ' ')"
assert_eq "re-install creates no new backups (idempotent)" "$backups_before" "$backups_after"
assert_eq "tmux.conf still a valid symlink after re-install" \
  "yes" "$([[ -L "$tmp_rt/.config/tmux/tmux.conf" && -e "$tmp_rt/.config/tmux/tmux.conf" ]] && echo yes || echo no)"

# round trip: uninstall removes every owned link and restores the backup
HOME="$tmp_rt" "$REPO_ROOT/bin/dotfiles" uninstall --yes >/dev/null 2>&1
uninstall_rc=$?
assert_eq "round-trip uninstall exits 0" "0" "$uninstall_rc"
assert_eq "tmux link removed on uninstall" \
  "no" "$([[ -L "$tmp_rt/.config/tmux/tmux.conf" ]] && echo yes || echo no)"
assert_eq "zshenv link removed on uninstall" \
  "no" "$([[ -L "$tmp_rt/.zshenv" ]] && echo yes || echo no)"
assert_eq "bin link removed on uninstall" \
  "no" "$([[ -L "$tmp_rt/.local/bin/mkx" ]] && echo yes || echo no)"
assert_eq "uninstall restored the pre-install tmux.conf" \
  "my old tmux" "$(cat "$tmp_rt/.config/tmux/tmux.conf" 2>/dev/null || echo MISSING)"
assert_eq "manifest deleted on full uninstall" \
  "no" "$([[ -f "$tmp_rt/.config/.dotfiles-manifest" ]] && echo yes || echo no)"
rm -rf "$tmp_rt"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
