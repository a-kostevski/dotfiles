# Zsh startup robustness and reproducibility — design (ZSH-04..09)

Date: 2026-07-14
Branch: `zsh`
Source review: `docs/REVIEW-2026-07-14.md` (findings ZSH-04 through ZSH-09)

## Goal

Make interactive Zsh startup portable across minimal servers, safe by default,
and reproducible, without weakening the security posture established by
ZSH-01..03. Every behavior change is covered by a test in `tests/test-zsh.sh`,
which runs under `make test`. Zsh config must stay parseable (`zsh -n`) and the
shellcheck bash gate must not regress.

## Context that shaped the design

- `config/zsh` is linked as a `tree` entry: `~/.config/zsh` is a real directory
  and each tracked file is an individual symlink back into the repo. A file
  committed at `config/zsh/plugins.lock` therefore appears at
  `$ZDOTDIR/plugins.lock`, and writing through that symlink writes the repo file.
- `~/.config/zsh/plugins/` is a **runtime** directory (cloned plugins), outside
  the repository. The lock file lives in the repo; the clones do not.
- `zshenv` is sourced for every Zsh invocation (including `zsh -c` scripts), so
  work added there must stay cheap.
- Helpers already exist: `command_exists`, `is_macos`/`is_linux`,
  `get_file_mtime` (`config/zsh/lib/platform.zsh`).

## Decisions (confirmed with the user)

1. **Plugin pinning (ZSH-08):** committed lock manifest + explicit update command.
2. **Locale (ZSH-04):** detect the best available UTF-8 locale; never force `LC_ALL`.
3. **compinit policy (ZSH-07):** `compinit -i` (ignore insecure dirs, no prompt),
   with content-based cache invalidation.

---

## ZSH-04 — Locale detection (`config/zsh/zshenv`)

Replace the unconditional

```zsh
export LANG="en_GB.UTF-8"
export LC_ALL=${LANG}
```

with detection inside an anonymous function (proper local scope, no leaked
variables, no top-level `local`):

```zsh
# Set LANG to the best available UTF-8 locale. Do not export LC_ALL globally;
# reserve it for individual commands needing deterministic locale behavior.
() {
  emulate -L zsh
  command -v locale >/dev/null 2>&1 || return
  local -a avail
  avail=(${(f)"$(locale -a 2>/dev/null)"})
  local want
  for want in en_GB.UTF-8 en_GB.utf8 en_US.UTF-8 en_US.utf8 C.UTF-8 C.utf8; do
    if (( ${avail[(Ie)$want]} )); then
      export LANG=$want
      return
    fi
  done
}
```

- `LC_ALL` is no longer exported at all.
- Preference order keeps `en_GB` first, then `en_US`, then `C.UTF-8`; both glibc
  (`.utf8`) and BSD/macOS (`.UTF-8`) spellings are checked.
- If `locale` is absent or no candidate is available, `LANG` is left as the
  environment provides it (no forced value on a minimal box).
- Cost: one `locale -a` fork, guarded by `command -v locale`. Accepted tradeoff
  for correctness; noted here so it is a conscious choice.

## ZSH-05 — Broken/unsafe aliases (`config/zsh/rc.d/60-aliases.zsh`)

- `clconfig`: convert the space-containing `cd` to a function with a quoted path:
  ```zsh
  clconfig() { cd "$HOME/Library/Application Support/Claude/" }
  ```
- `macos_config`: **remove** the alias entirely. It sourced privileged
  provisioning scripts (`macos/defaults`, `macos/harden`, also missing their
  `.zsh` suffixes) into the interactive shell. Provisioning is already behind
  explicit bootstrap flags (`--apply-macos-defaults`, `--harden`); the shell must
  not re-source it.
- `geoip`: `curl ipinfo.io/` → `curl https://ipinfo.io/`.
- `publicip4`: `curl http://ipinfo.io/ip` → `curl https://ipinfo.io/ip`.

No other aliases change.

## ZSH-06 — fzf initialization (`config/zsh/rc.d/71-plugins.zsh`)

Capture `fzf --zsh` once and source it only on success:

```zsh
if command_exists fzf; then
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n "$_fzf_init" ]]; then
    source <(print -r -- "$_fzf_init")
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
  unset _fzf_init
fi
```

`fzf --zsh` is now invoked exactly once (previously twice: a feature check plus
generation).

## ZSH-07 — Content-based completion cache (`config/zsh/rc.d/30-completions.zsh`)

Replace the day-of-year logic (lines ~34-51) with content-based invalidation and
an explicit ignore-insecure policy:

```zsh
ZSH_COMPDUMP=$zsh_cache_dir/zcompdump

# Regenerate the dump when it is missing/empty or any fpath directory is newer
# than it, so a completion added later the same day is registered immediately.
# `-i` ignores insecure directories instead of prompting, keeping startup
# non-interactive and never sourcing world/group-writable completion dirs.
_compdump_stale() {
  emulate -L zsh
  local dump="$1" d
  [[ -s "$dump" ]] || return 0
  for d in $fpath; do
    [[ -d "$d" && "$d" -nt "$dump" ]] && return 0
  done
  return 1
}

if _compdump_stale "$ZSH_COMPDUMP"; then
  compinit -i -d "$ZSH_COMPDUMP"
else
  compinit -C -d "$ZSH_COMPDUMP"
fi
unfunction _compdump_stale
unset ZSH_COMPDUMP zsh_cache_dir
```

- The `.compdump_check` day file and the `get_day_of_year` call are removed.
- `zsh_cache_dir` and control vars stop being top-level `local` (they are plain,
  then `unset`), addressing part of ZSH-09.
- Directory `-nt` comparison detects new completion files (adding a file bumps the
  containing directory's mtime) and freshly cloned plugin dirs.

## ZSH-08 — Plugin pinning + update command

### Lock manifest

New tracked file `config/zsh/plugins.lock` (linked to `$ZDOTDIR/plugins.lock`):

```
# Zsh plugin lock file. Managed by `_plug_update`; format: owner/repo <sha>
romkatv/zsh-defer 53a26e287fbbe2dcebb3aa1801546c6de32416fa
zsh-users/zsh-autosuggestions 0e810e5afa27acbd074398eefbe28d13005dbc15
zsh-users/zsh-completions c29efd0bc3927ab25dc93ad4085d7143881b73f0
zsh-users/zsh-syntax-highlighting 5eb677bb0fa9a3e60f0eff031dc13926e093df92
```

Initial SHAs are the currently-installed, known-good revisions.

### Runtime changes (`config/zsh/rc.d/70-zsh-unplugged.zsh`)

- `_plug_locked_rev <owner/repo>`: reads `${ZPLUGIN_LOCK:-$ZDOTDIR/plugins.lock}`
  (overridable env var for tests), echoes the pinned SHA, or returns non-zero.
- `_plug_fetch <owner/repo> <plugdir>`: shared clone helper used by both
  `_plug_clone` and `_plug_load` (removes duplicated clone logic — ZSH-09). If the
  repo is pinned, do a full `git clone` then `git -C <dir> checkout -q <sha>` (a
  shallow clone cannot check out an arbitrary SHA; these repos are tiny). If not
  pinned, keep the existing shallow clone.
- `_plug_clone`/`_plug_load` call `_plug_fetch`, then keep their existing
  initfile-symlink and (for load) `fpath`/source behavior.
- `_plug_update`: pull each plugin to its remote default HEAD (`git pull --ff-only
  --recurse-submodules --autostash`), then rewrite the lock from the resulting
  checkouts via `_plug_write_lock`. This is the **only** command that moves
  plugins off their pinned revisions.
- `_plug_write_lock`: for each cloned plugin, derive `owner/repo` from
  `git remote get-url origin` and the SHA from `git rev-parse HEAD`, then write a
  sorted lock file. Writing through the `$ZDOTDIR/plugins.lock` symlink updates the
  tracked repo file, ready to commit.
- `_plug_compile` (defined but never called) is removed (ZSH-09).

Security: on first startup the pinned SHA is what gets checked out, so a moving
branch can no longer be silently sourced. Updates are explicit and reviewable as
a lock-file diff.

## ZSH-09 — Batched safe items

Included (each tested where it changes behavior):

- Remove unused `_plug_compile` and the now-unused `get_day_of_year`.
- `command_exists`: stop caching **negative** results so a command installed in
  the current shell is detected on the next check. Positive results stay cached
  (a present command rarely disappears mid-session).
- PATH/FPATH dedup: declare `typeset -U path PATH` (in `profile.d/10-path.zsh`) and
  `typeset -U fpath FPATH` (in `profile.d/00-fpath.zsh`); simplify `append_path`/
  `prepend_path`/`append_fpath` to drop the fragile `=~ " $dir "` regex match while
  keeping the `-d` existence guard. Exact dedup via unique arrays.
- Top-level `local` removed in the files touched above (30-completions, zshenv).

Deferred (noted, not done — higher risk / out of scope):

- Consolidating fzf/1Password/uv completion *generation vs startup policy* across
  files is an architectural refactor beyond these findings; left as-is.
- Sweeping every remaining top-level `local` in files not otherwise touched.

## Testing (`tests/test-zsh.sh`)

Extends the existing isolated-`HOME` harness. New reusable stubs:

- **fake `fzf`**: records each `--zsh` invocation to a counter file.
- **fake `git`**: dispatches on subcommand (`clone` creates the target dir + a
  dummy `*.plugin.zsh`; `checkout`/`-C`/`remote get-url`/`rev-parse` are logged or
  return canned values) so plugin flows run without network.

New assertions:

1. **ZSH-04:** after sourcing `zshenv`, `LC_ALL` is empty; if `LANG` is set it
   appears in `locale -a`.
2. **ZSH-05:** `macos_config` is undefined; `clconfig` is a function; the `geoip`
   and `publicip4` definitions use `https://` and contain no `http://`.
3. **ZSH-06:** with the fake `fzf`, sourcing `71-plugins.zsh` (fake `git` stubbing
   clones) invokes `fzf --zsh` exactly once.
4. **ZSH-07:** dump is created on first run; setting an `fpath` directory's mtime
   to the future forces regeneration on the next run; a group-writable `fpath`
   directory produces no `insecure` warning on stderr (verifies `-i`).
5. **ZSH-08:** `_plug_locked_rev` returns the SHA for a listed repo and non-zero
   for an absent one (via `ZPLUGIN_LOCK`); `_plug_fetch` on a pinned repo performs
   a `checkout` to the pinned SHA (via fake `git` log); `_plug_write_lock` emits a
   correctly formatted, sorted lock from fake-git remotes/HEADs.
6. **ZSH-09:** `command_exists` detects a command that appears on `PATH` after an
   initial negative check; `path`/`fpath` contain no duplicates after sourcing the
   profile.d helpers twice.

`make test` (including the existing ZSH-01..03 assertions) must stay green.

## Out of scope

ZSH-01/02/03 (resolved); all non-Zsh findings; the deferred items listed under
ZSH-09.

## Review bookkeeping

On completion, mark ZSH-04..09 Resolved in `docs/REVIEW-2026-07-14.md` in the
existing style, each with the fixing commit hash.
