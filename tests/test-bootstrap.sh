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

echo "== manifest profile selection =="
# shellcheck source=/dev/null
source "$REPO_ROOT/install/lib.sh"
export dot_root="$REPO_ROOT"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/symlinks.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/install/manifest.sh"

assert_contains "minimal selects git" "git|tree" "$(manifest_select minimal macos)"
assert_eq "minimal excludes nvim" "" "$(manifest_select minimal macos | grep '^nvim|' || true)"
assert_contains "standard adds nvim" "nvim|tree" "$(manifest_select standard macos)"

full_macos_links="$(manifest_links full macos)"
assert_contains "full/macos links kitty" "/config/kitty/" "$full_macos_links"
assert_contains "full maps curl to home" "$REPO_ROOT/config/.curlrc|$HOME/.curlrc" "$full_macos_links"
assert_contains "full maps clang-format to home" "$REPO_ROOT/config/clang-format|$HOME/.clang-format" "$full_macos_links"

assert_eq "full/ubuntu has no macOS extras" "" \
  "$(manifest_links full ubuntu | grep -E '/config/(karabiner|kitty|homebrew)/' || true)"

if validate_profile bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "  FAIL: unknown profile should be rejected"
else
  PASS=$((PASS + 1)); echo "  ok: unknown profile rejected"
fi
if validate_profile custom >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "  FAIL: custom profile should be rejected"
else
  PASS=$((PASS + 1)); echo "  ok: custom profile rejected"
fi

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
assert_contains "Ubuntu installer pins supported Neovim" \
  "NEOVIM_RELEASE_VERSION=\"0.11.4\"" "$ubuntu_installer"

ubuntu_version_rc() (
  # install-ubuntu enables strict mode when sourced; disable errexit after it
  # so the expected failing comparison can be asserted by this test harness.
  # shellcheck source=/dev/null
  source "$REPO_ROOT/install/install-ubuntu.sh"
  set +e
  neovim_version_at_least "$1"
  echo $?
)
assert_eq "Neovim minimum accepts 0.11.0" "0" "$(ubuntu_version_rc 0.11.0)"
assert_eq "Neovim minimum accepts later release" "0" "$(ubuntu_version_rc 0.12.1)"
assert_eq "Neovim minimum rejects 0.10" "1" "$(ubuntu_version_rc 0.10.4)"

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
all_comps="$(manifest_components all macos)"
for excluded in macos ubuntu defaults security; do
  assert_eq "all profile excludes $excluded" "" "$(grep -x "$excluded" <<<"$all_comps" || true)"
done
assert_contains "all profile still includes real configs" "nvim" "$all_comps"

echo "== bash version guard =="
# Stock macOS bash is 3.2; manifest.sh needs bash 4+ (declare -gA). The entry
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
ln -s "$tmp_clean/nonexistent" "$tmp_clean/.config/owned-deadlink"
ln -s "$tmp_clean/nonexistent" "$tmp_clean/.config/foreign-deadlink"
printf '2026-01-01 00:00:00|%s/config/tmux/tmux.conf|%s/.config/owned-deadlink\n' \
  "$REPO_ROOT" "$tmp_clean" >"$tmp_clean/.config/.dotfiles-manifest"
clean_dry_out="$(HOME="$tmp_clean" MANIFEST_FILE="$tmp_clean/.config/.dotfiles-manifest" clean_broken_symlinks dry_run)"
assert_contains "dry clean reports the broken link" \
  "Would remove: $tmp_clean/.config/owned-deadlink" "$clean_dry_out"
assert_contains "dry clean says would-remove, not found" \
  "Would remove 1 broken symlink" "$clean_dry_out"
assert_eq "dry clean leaves the link in place" \
  "yes" "$([[ -L "$tmp_clean/.config/owned-deadlink" ]] && echo yes || echo no)"
clean_out="$(HOME="$tmp_clean" MANIFEST_FILE="$tmp_clean/.config/.dotfiles-manifest" clean_broken_symlinks "")"
assert_contains "real clean reports removal count" \
  "Removed 1 broken symlink" "$clean_out"
assert_eq "real clean removes the link" \
  "no" "$([[ -L "$tmp_clean/.config/owned-deadlink" ]] && echo yes || echo no)"
assert_eq "manifest cleanup preserves foreign broken link" \
  "yes" "$([[ -L "$tmp_clean/.config/foreign-deadlink" ]] && echo yes || echo no)"
rm -rf "$tmp_clean"

echo "== sync mode dry run =="
# Safety net for set -u/pipefail: the full sync path must still run clean
tmp_sync="$(mktemp -d)"
sync_out="$(HOME="$tmp_sync" ./bootstrap.sh --sync --dry-run --profile minimal 2>&1)"
sync_rc=$?
assert_eq "sync dry run exits 0" "0" "$sync_rc"
assert_contains "sync dry run completes" "Sync completed successfully" "$sync_out"
rm -rf "$tmp_sync"

echo "== stored profile sync =="
tmp_profile="$(mktemp -d)"
HOME="$tmp_profile" ./bootstrap.sh --sync --profile minimal >/dev/null 2>&1
HOME="$tmp_profile" "$REPO_ROOT/bin/dotfiles" profile standard >/dev/null 2>&1
HOME="$tmp_profile" "$REPO_ROOT/bin/dotfiles" sync >/dev/null 2>&1
assert_eq "default sync applies stored profile" \
  "yes" "$([[ -L "$tmp_profile/.config/nvim/init.lua" ]] && echo yes || echo no)"
HOME="$tmp_profile" "$REPO_ROOT/bin/dotfiles" status --summary >/dev/null 2>&1
assert_eq "profile-aware healthy status exits zero" "0" "$?"
rm "$tmp_profile/.config/nvim/init.lua"
if HOME="$tmp_profile" "$REPO_ROOT/bin/dotfiles" status --summary >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: profile-aware status should fail for a missing expected link"
else
  PASS=$((PASS + 1))
  echo "  ok: profile-aware status fails for a missing expected link"
fi
rm -rf "$tmp_profile"

echo "== bare-name sync of a file-backed component =="
tmp_fc="$(mktemp -d)"
HOME="$tmp_fc" "$REPO_ROOT/bin/dotfiles" sync curl >/dev/null 2>&1
assert_eq "bare-name sync curl links ~/.curlrc" \
  "$REPO_ROOT/config/.curlrc" "$(readlink "$tmp_fc/.curlrc" 2>/dev/null)"
rm -rf "$tmp_fc"

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
