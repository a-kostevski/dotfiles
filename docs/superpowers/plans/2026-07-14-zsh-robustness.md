# Zsh Startup Robustness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Zsh findings ZSH-04..09 — portable locale, safe aliases, single fzf init, content-based completion cache, pinned/lockable plugins, and batched correctness cleanups — each covered by a test.

**Architecture:** Edit modular Zsh sources under `config/zsh/` (never `~/.config`). Add behavioral regression tests to `tests/test-zsh.sh`, which runs under `make test` using an isolated `HOME` and `zsh -dfc`. Plugin reproducibility uses a committed lock manifest read at clone time and rewritten by an explicit update command.

**Tech Stack:** Zsh, Bash test harness (`tests/lib.sh`: `assert_eq`, `$PASS`/`$FAIL`), git.

## Global Constraints

- Never edit `~/.config/` directly — edit `config/zsh/` sources; tests sync via `bootstrap.sh --sync`.
- Keep Zsh config parseable: `zsh -n <file>` must pass. Do not regress the shellcheck bash gate (Zsh files are not shellchecked).
- Every behavior change needs a test in `tests/test-zsh.sh`. `make test` must stay green.
- Do not weaken security: `macos_config` stays removed; plugins load at pinned revisions; `compinit -i` never sources insecure dirs.
- **Commits are deferred:** the user asked not to commit/push unless explicitly requested. Each task's "Commit" step means *stage and hold*; only run `git commit` when the user asks. Work stays on branch `zsh`.
- Preferred locale order: `en_GB.UTF-8 en_GB.utf8 en_US.UTF-8 en_US.utf8 C.UTF-8 C.utf8`. `LC_ALL` must not be exported globally.
- Initial plugin lock SHAs (known-good, currently installed):
  - `romkatv/zsh-defer 53a26e287fbbe2dcebb3aa1801546c6de32416fa`
  - `zsh-users/zsh-autosuggestions 0e810e5afa27acbd074398eefbe28d13005dbc15`
  - `zsh-users/zsh-completions c29efd0bc3927ab25dc93ad4085d7143881b73f0`
  - `zsh-users/zsh-syntax-highlighting 5eb677bb0fa9a3e60f0eff031dc13926e093df92`

---

### Task 1: ZSH-05 — safe aliases

**Files:**
- Modify: `config/zsh/rc.d/60-aliases.zsh` (lines 21, 39, 41, 140)
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Produces: alias file where `clconfig` is a function, `macos_config` is absent, `geoip`/`publicip4` use HTTPS.

- [ ] **Step 1: Write failing test** — append before the final summary block in `tests/test-zsh.sh`:

```bash
echo "== ZSH-05 aliases =="
alias_out="$(
  HOME="$tmp_home" XDG_DATA_HOME="$tmp_home/.local/share" \
    XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/60-aliases.zsh" 2>/dev/null
    print -r -- "macos_config=$(whence -w macos_config 2>/dev/null)"
    print -r -- "clconfig=$(whence -w clconfig 2>/dev/null)"
  '
)"
assert_eq "macos_config alias is removed" "" \
  "$(grep -c macos_config <<<"$alias_out" | grep -v 0 || true; grep 'macos_config: alias' <<<"$alias_out" || true)"
assert_eq "clconfig is a function" "clconfig: function" "$(grep '^clconfig=' <<<"$alias_out" | sed 's/^clconfig=//')"
assert_eq "geoip uses https" "yes" \
  "$([[ "$(grep -E '^alias geoip=' "$REPO_ROOT/config/zsh/rc.d/60-aliases.zsh")" == *https://* ]] && echo yes || echo no)"
assert_eq "publicip4 uses https" "yes" \
  "$(grep -E '^alias publicip4=' "$REPO_ROOT/config/zsh/rc.d/60-aliases.zsh" | grep -q 'http://' && echo no || echo yes)"
```

- [ ] **Step 2: Run to verify failure** — `make test` (or `bash tests/test-zsh.sh`). Expected: the four ZSH-05 assertions fail.

- [ ] **Step 3: Implement** in `config/zsh/rc.d/60-aliases.zsh`:
  - Line 21 `alias clconfig=...` → replace with `clconfig() { cd "$HOME/Library/Application Support/Claude/" }`
  - Line 39 `alias geoip="curl ipinfo.io/"` → `alias geoip="curl https://ipinfo.io/"`
  - Line 41 `alias publicip4="curl http://ipinfo.io/ip"` → `alias publicip4="curl https://ipinfo.io/ip"`
  - Line 140 `alias macos_config=...` → delete the entire line.

- [ ] **Step 4: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: ZSH-05 assertions pass; total `FAIL` count 0.

- [ ] **Step 5: Parse check** — `zsh -n config/zsh/rc.d/60-aliases.zsh`. Expected: no output.

- [ ] **Step 6: Commit (deferred)** — `git add config/zsh/rc.d/60-aliases.zsh tests/test-zsh.sh` (hold; commit only when user asks).

---

### Task 2: ZSH-04 — locale detection

**Files:**
- Modify: `config/zsh/zshenv:99-100`
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Produces: `zshenv` that exports `LANG` (best available) and never exports `LC_ALL`.

- [ ] **Step 1: Write failing test** in `tests/test-zsh.sh`:

```bash
echo "== ZSH-04 locale =="
locale_out="$(
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    print -r -- "LC_ALL=[${LC_ALL-unset}]"
    if [[ -n "$LANG" ]]; then
      locale -a 2>/dev/null | grep -qxF "$LANG" && print -r -- "LANG_OK=yes" || print -r -- "LANG_OK=no"
    else
      print -r -- "LANG_OK=yes"
    fi
  '
)"
assert_eq "LC_ALL is not exported globally" "LC_ALL=[unset]" "$(grep '^LC_ALL=' <<<"$locale_out")"
assert_eq "LANG is an available locale (or unset)" "LANG_OK=yes" "$(grep '^LANG_OK=' <<<"$locale_out")"
```

- [ ] **Step 2: Run to verify failure** — `bash tests/test-zsh.sh`. Expected: `LC_ALL is not exported globally` fails (currently `LC_ALL=[en_GB.UTF-8]`).

- [ ] **Step 3: Implement** — replace `config/zsh/zshenv` lines 99-100 (`export LANG=...` / `export LC_ALL=...`) with:

```zsh
# Set LANG to the best available UTF-8 locale. Do not export LC_ALL globally;
# reserve it for individual commands that need deterministic locale behavior.
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

(Leave `export EDITOR`/`export VISUAL` lines below unchanged.)

- [ ] **Step 4: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: ZSH-04 assertions pass.

- [ ] **Step 5: Parse check** — `zsh -n config/zsh/zshenv`. Expected: no output.

- [ ] **Step 6: Commit (deferred)** — `git add config/zsh/zshenv tests/test-zsh.sh` (hold).

---

### Task 3: ZSH-09 — command_exists negative cache + path/fpath dedup

**Files:**
- Modify: `config/zsh/lib/platform.zsh:26-42` (`command_exists`)
- Modify: `config/zsh/profile.d/10-path.zsh:1-13` (add `typeset -U`, simplify helpers)
- Modify: `config/zsh/profile.d/00-fpath.zsh:1-6` (add `typeset -U`, simplify helper)
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Produces: `command_exists` that does not cache negative results; `path`/`fpath` deduplicated by `typeset -U`.

- [ ] **Step 1: Write failing test** in `tests/test-zsh.sh`:

```bash
echo "== ZSH-09 command_exists + dedup =="
fake_bin="$tmp_runtime_root/fakebin"; mkdir -p "$fake_bin"
ce_out="$(
  HOME="$tmp_home" FAKE_BIN="$fake_bin" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    command_exists zqxtool && print -r -- "before=found" || print -r -- "before=absent"
    print -r -- "#!/bin/sh" > "$FAKE_BIN/zqxtool"; chmod +x "$FAKE_BIN/zqxtool"
    path=("$FAKE_BIN" $path); rehash
    command_exists zqxtool && print -r -- "after=found" || print -r -- "after=absent"
  '
)"
assert_eq "command_exists sees a newly installed command" "$(printf 'before=absent\nafter=found')" \
  "$(grep -E '^(before|after)=' <<<"$ce_out")"

dedup_out="$(
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" \
    XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state" \
    XDG_CACHE_HOME="$tmp_home/.cache" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/profile.d/10-path.zsh"
    source "$ZDOTDIR/profile.d/10-path.zsh"
    source "$ZDOTDIR/profile.d/00-fpath.zsh"
    source "$ZDOTDIR/profile.d/00-fpath.zsh"
    print -r -- "path_dups=$(( ${#path} - ${#${(u)path}} ))"
    print -r -- "fpath_dups=$(( ${#fpath} - ${#${(u)fpath}} ))"
  '
)"
assert_eq "path has no duplicates" "path_dups=0" "$(grep '^path_dups=' <<<"$dedup_out")"
assert_eq "fpath has no duplicates" "fpath_dups=0" "$(grep '^fpath_dups=' <<<"$dedup_out")"
```

- [ ] **Step 2: Run to verify failure** — `bash tests/test-zsh.sh`. Expected: `command_exists sees a newly installed command` fails (`after=absent`, stale negative cache).

- [ ] **Step 3a: Implement `command_exists`** — replace the body in `config/zsh/lib/platform.zsh` so negatives are not cached:

```zsh
command_exists() {
  local cmd="$1"

  # Positive results are cached; a present command rarely disappears mid-session.
  if (( ${+_cmd_cache[$cmd]} )); then
    return 0
  fi

  if command -v "$cmd" &>/dev/null; then
    _cmd_cache[$cmd]=0
    return 0
  fi
  # Do not cache the miss: a command installed later this session must be seen.
  return 1
}
```

- [ ] **Step 3b: Implement path dedup** — at the top of `config/zsh/profile.d/10-path.zsh` add `typeset -U path PATH` as the first line, then simplify the helpers to drop the regex match:

```zsh
typeset -U path PATH

append_path() {
   local dir="$1"
   [[ -d "$dir" ]] && path+=("$dir")
}

prepend_path() {
   local dir="$1"
   [[ -d "$dir" ]] && path=("$dir" "${path[@]}")
}
```

(Leave the rest of the file — the `prepend_path`/`append_path` call list — unchanged.)

- [ ] **Step 3c: Implement fpath dedup** — at the top of `config/zsh/profile.d/00-fpath.zsh` add `typeset -U fpath FPATH` as the first line, then simplify:

```zsh
typeset -U fpath FPATH

append_fpath() {
   local dir="$1"
   [[ -d "$dir" ]] && fpath+=("$dir")
}
```

(Leave the Homebrew/append call list below unchanged.)

- [ ] **Step 4: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: the three ZSH-09 assertions pass.

- [ ] **Step 5: Parse check** — `zsh -n config/zsh/lib/platform.zsh config/zsh/profile.d/10-path.zsh config/zsh/profile.d/00-fpath.zsh`. Expected: no output.

- [ ] **Step 6: Commit (deferred)** — `git add config/zsh/lib/platform.zsh config/zsh/profile.d/10-path.zsh config/zsh/profile.d/00-fpath.zsh tests/test-zsh.sh` (hold).

---

### Task 4: ZSH-07 — content-based completion cache + compinit -i

**Files:**
- Modify: `config/zsh/rc.d/30-completions.zsh:27-52`
- Modify: `config/zsh/lib/platform.zsh` (remove now-unused `get_day_of_year`, lines 107-110)
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Consumes: `$XDG_CACHE_HOME/zsh` cache dir (created in this file).
- Produces: dump at `$XDG_CACHE_HOME/zsh/zcompdump`, regenerated when any `fpath` dir is newer.

- [ ] **Step 1: Write failing test** in `tests/test-zsh.sh`:

```bash
echo "== ZSH-07 completion cache =="
comp_env=(HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config"
  XDG_DATA_HOME="$tmp_home/.local/share" XDG_STATE_HOME="$tmp_home/.local/state"
  XDG_CACHE_HOME="$tmp_home/.cache")
run_comp() {
  env "${comp_env[@]}" zsh -dfc '
    source "$HOME/.zshenv"
    source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/profile.d/00-fpath.zsh"
    source "$ZDOTDIR/rc.d/30-completions.zsh"
  ' 2>"$tmp_runtime_root/comp_err"
}
dump="$tmp_home/.cache/zsh/zcompdump"
run_comp
assert_eq "compdump created on first run" "yes" "$([[ -s "$dump" ]] && echo yes || echo no)"
mtime1="$(get_file_mtime_host "$dump")"
# fast path: no fpath dir newer than dump -> dump not rewritten
sleep 1; run_comp
mtime2="$(get_file_mtime_host "$dump")"
assert_eq "compdump kept when nothing changed" "$mtime1" "$mtime2"
# content change: make an fpath dir newer than the dump -> regenerate
touch -t 203012312359 "$tmp_home/.config/zsh/functions"
sleep 1; run_comp
mtime3="$(get_file_mtime_host "$dump")"
assert_eq "compdump regenerates when fpath dir is newer" "yes" \
  "$([[ "$mtime3" != "$mtime2" ]] && echo yes || echo no)"
# compinit -i: a group-writable fpath dir produces no insecure warning
insecure="$tmp_home/.config/zsh/functions"; chmod g+w "$insecure"
run_comp
assert_eq "no insecure-directory warning with compinit -i" "" \
  "$(grep -i insecure "$tmp_runtime_root/comp_err" || true)"
```

Add this host mtime helper near the top of `tests/test-zsh.sh` (after `mode_of`):

```bash
get_file_mtime_host() { stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1"; }
```

- [ ] **Step 2: Run to verify failure** — `bash tests/test-zsh.sh`. Expected: `compdump regenerates when fpath dir is newer` fails (current logic is day-based).

- [ ] **Step 3a: Implement** — in `config/zsh/rc.d/30-completions.zsh`, replace the block from `local zsh_cache_dir=...` (line 27) through `_comp_options+=(globdots)` handling of the dump (lines 27-52), i.e. lines 27-51, with:

```zsh
zsh_cache_dir="$XDG_CACHE_HOME/zsh"
if [[ ! -d "$zsh_cache_dir" ]]; then
    command mkdir -p -m 0700 "$zsh_cache_dir" || return 1
fi

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
_comp_options+=(globdots)
```

- [ ] **Step 3b: Remove dead helper** — delete `get_day_of_year()` (lines 107-110) from `config/zsh/lib/platform.zsh`.

- [ ] **Step 4: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: all ZSH-07 assertions pass; the ZSH-01 cache-dir assertions still pass.

- [ ] **Step 5: Parse check** — `zsh -n config/zsh/rc.d/30-completions.zsh config/zsh/lib/platform.zsh`. Expected: no output.

- [ ] **Step 6: Commit (deferred)** — `git add config/zsh/rc.d/30-completions.zsh config/zsh/lib/platform.zsh tests/test-zsh.sh` (hold).

---

### Task 5: ZSH-08 — plugin lock manifest, pinning, and update command

**Files:**
- Create: `config/zsh/plugins.lock`
- Modify: `config/zsh/rc.d/70-zsh-unplugged.zsh` (rewrite clone path; add lock helpers; remove `_plug_compile`)
- Modify: `tests/lib.sh` (add `make_fake_bin` stub helper)
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Produces:
  - `_plug_locked_rev <owner/repo>` → echoes SHA / returns 1; reads `${ZPLUGIN_LOCK:-${ZDOTDIR}/plugins.lock}`.
  - `_plug_fetch <owner/repo> <plugdir>` → clones if absent; checks out the pinned SHA when locked.
  - `_plug_write_lock` → rewrites the lock from each clone's `remote get-url origin` + `rev-parse HEAD`.
  - `_plug_update` → pulls each plugin then calls `_plug_write_lock`.

- [ ] **Step 1: Create the lock file** `config/zsh/plugins.lock`:

```
# Zsh plugin lock file. Managed by `_plug_update`.
# Format: owner/repo <commit-sha>
romkatv/zsh-defer 53a26e287fbbe2dcebb3aa1801546c6de32416fa
zsh-users/zsh-autosuggestions 0e810e5afa27acbd074398eefbe28d13005dbc15
zsh-users/zsh-completions c29efd0bc3927ab25dc93ad4085d7143881b73f0
zsh-users/zsh-syntax-highlighting 5eb677bb0fa9a3e60f0eff031dc13926e093df92
```

- [ ] **Step 2: Add stub helper** to `tests/lib.sh` (end of file):

```bash
# make_fake_bin <dir> <name> <body> — create an executable stub on a fake PATH.
make_fake_bin() {
  local dir="$1" name="$2" body="$3"
  mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$body"; } > "$dir/$name"
  chmod +x "$dir/$name"
}
```

- [ ] **Step 3: Write failing test** in `tests/test-zsh.sh`:

```bash
echo "== ZSH-08 plugin lock =="
lock="$tmp_runtime_root/plugins.lock"
printf '# c\nzsh-users/zsh-autosuggestions abc123\nromkatv/zsh-defer def456\n' > "$lock"
locked_out="$(
  HOME="$tmp_home" ZPLUGIN_LOCK="$lock" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    print -r -- "hit=$(_plug_locked_rev zsh-users/zsh-autosuggestions)"
    _plug_locked_rev zsh-users/nope >/dev/null && print -r -- "miss=found" || print -r -- "miss=absent"
  '
)"
assert_eq "locked rev returns pinned sha" "hit=abc123" "$(grep '^hit=' <<<"$locked_out")"
assert_eq "locked rev misses unlisted repo" "miss=absent" "$(grep '^miss=' <<<"$locked_out")"

# _plug_fetch checks out the pin using a fake git that logs its args.
fake_git="$tmp_runtime_root/gitstub"
make_fake_bin "$fake_git" git '
case "$1" in
  clone) dest="${@: -1}"; mkdir -p "$dest"; echo "clone $dest" >>"$GIT_LOG"; : > "$dest/plugin.plugin.zsh" ;;
  -C) shift; d="$1"; shift; echo "-C $d $*" >>"$GIT_LOG"
      case "$1 $2" in "remote get-url") echo "https://github.com/zsh-users/zsh-autosuggestions.git";;
        "rev-parse HEAD") echo abc123def;; esac ;;
esac
exit 0'
fetch_log="$tmp_runtime_root/git_fetch.log"; : > "$fetch_log"
plugdir="$tmp_runtime_root/plug/zsh-autosuggestions"
PATH="$fake_git:$PATH" GIT_LOG="$fetch_log" ZPLUGIN_LOCK="$lock" \
  HOME="$tmp_home" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    _plug_fetch zsh-users/zsh-autosuggestions "'"$plugdir"'"
  '
assert_eq "pinned fetch checks out the locked sha" "yes" \
  "$(grep -q 'checkout -q abc123' "$fetch_log" && echo yes || echo no)"

# _plug_write_lock emits sorted owner/repo <sha> from fake-git remotes/HEADs.
wl_root="$tmp_runtime_root/wl"; mkdir -p "$wl_root/zsh-autosuggestions/.git" "$wl_root/zsh-defer/.git"
out_lock="$tmp_runtime_root/out.lock"
PATH="$fake_git:$PATH" GIT_LOG="$fetch_log" ZPLUGINDIR="$wl_root" ZPLUGIN_LOCK="$out_lock" \
  HOME="$tmp_home" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    _plug_write_lock
  ' >/dev/null
assert_eq "write_lock records owner/repo and sha" "yes" \
  "$(grep -q 'zsh-users/zsh-autosuggestions abc123def' "$out_lock" && echo yes || echo no)"

assert_eq "_plug_compile is removed" "" \
  "$(grep -c '_plug_compile' "$REPO_ROOT/config/zsh/rc.d/70-zsh-unplugged.zsh" | grep -v '^0$' || true)"
```

Note: the fake git returns the same remote/sha for every dir (stub simplification); the assertion only checks the autosuggestions line is present and correctly formatted.

- [ ] **Step 4: Run to verify failure** — `bash tests/test-zsh.sh`. Expected: ZSH-08 assertions fail (functions undefined).

- [ ] **Step 5: Implement** — rewrite `config/zsh/rc.d/70-zsh-unplugged.zsh`. Keep the file header comment. Replace the body with:

```zsh
# https://github.com/mattmc3/zsh_unplugged (adapted)
# Minimal zsh plugin manager with a committed revision lock.

_plug_lockfile() { print -r -- "${ZPLUGIN_LOCK:-${ZDOTDIR:-$HOME/.config/zsh}/plugins.lock}"; }

# _plug_locked_rev <owner/repo> -> pinned sha on stdout, or return 1.
function _plug_locked_rev {
  emulate -L zsh
  local repo="$1" lockfile line
  lockfile="$(_plug_lockfile)"
  [[ -r "$lockfile" ]] || return 1
  while IFS= read -r line; do
    [[ "$line" == \#* || -z "$line" ]] && continue
    if [[ "${line%% *}" == "$repo" ]]; then
      print -r -- "${line#* }"
      return 0
    fi
  done < "$lockfile"
  return 1
}

# _plug_fetch <owner/repo> <plugdir> -> clone if absent, at the locked rev if pinned.
function _plug_fetch {
  emulate -L zsh
  local repo="$1" plugdir="$2" rev
  [[ -d "$plugdir" ]] && return 0
  echo "Cloning $repo..."
  rev="$(_plug_locked_rev "$repo")"
  if [[ -n "$rev" ]]; then
    command git clone -q --recursive "https://github.com/$repo" "$plugdir" \
      && command git -C "$plugdir" checkout -q "$rev" \
      || { echo >&2 "Failed to clone/pin $repo"; return 1; }
  else
    command git clone -q --depth 1 --recursive --shallow-submodules \
      "https://github.com/$repo" "$plugdir" \
      || { echo >&2 "Failed to clone $repo"; return 1; }
  fi
}

# _plug_clone <owner/repo> [...] -> ensure cloned + an initfile symlink exists.
function _plug_clone {
  local repo plugdir initfile initfiles
  ZPLUGINDIR=${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}
  for repo in $@; do
    plugdir=$ZPLUGINDIR/${repo:t}
    initfile=$plugdir/${repo:t}.plugin.zsh
    _plug_fetch "$repo" "$plugdir" || continue
    if [[ ! -e $initfile ]]; then
      initfiles=($plugdir/*.{plugin.zsh,zsh-theme,zsh,sh}(N))
      (( $#initfiles )) && ln -sf $initfiles[1] $initfile
    fi
  done
}

# _plug_load <owner/repo> [...] -> clone, add to fpath, and source.
function _plug_load {
  local repo plugdir initfile initfiles
  ZPLUGINDIR=${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}
  for repo in $@; do
    plugdir=$ZPLUGINDIR/${repo:t}
    initfile=$plugdir/${repo:t}.plugin.zsh
    _plug_fetch "$repo" "$plugdir" || continue
    if [[ ! -e $initfile ]]; then
      initfiles=($plugdir/*.{plugin.zsh,zsh-theme,zsh,sh}(N))
      (( $#initfiles )) || { echo >&2 "No init file '$repo'." && continue }
      ln -sf $initfiles[1] $initfile
    fi
    fpath+=$plugdir
    (( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
  done
}

# _plug_source <dir> [...] -> source local plugin directories.
function _plug_source {
  local plugdir initfile
  ZPLUGINDIR=${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}
  for plugdir in $@; do
    [[ $plugdir = /* ]] || plugdir=$ZPLUGINDIR/$plugdir
    fpath+=$plugdir
    initfile=$plugdir/${plugdir:t}.plugin.zsh
    (( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
  done
}

# _plug_write_lock -> rewrite the lock from each clone's origin + HEAD.
function _plug_write_lock {
  emulate -L zsh
  ZPLUGINDIR=${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}
  local lockfile d url slug sha line
  local -a entries
  lockfile="$(_plug_lockfile)"
  for d in $ZPLUGINDIR/*/.git(/N); do
    url="$(command git -C "${d:h}" remote get-url origin 2>/dev/null)" || continue
    slug="${${url%.git}##*github.com[:/]}"
    sha="$(command git -C "${d:h}" rev-parse HEAD 2>/dev/null)" || continue
    entries+=("$slug $sha")
  done
  {
    print -r -- "# Zsh plugin lock file. Managed by \`_plug_update\`."
    print -r -- "# Format: owner/repo <commit-sha>"
    for line in "${(@o)entries}"; do print -r -- "$line"; done
  } > "$lockfile"
  echo "Wrote ${#entries} pinned revision(s) to $lockfile"
}

# _plug_update -> pull each plugin to its remote HEAD, then rewrite the lock.
# This is the only command that moves plugins off their pinned revisions.
function _plug_update {
  emulate -L zsh
  ZPLUGINDIR=${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}
  local d
  for d in $ZPLUGINDIR/*/.git(/N); do
    echo "Updating ${d:h:t}..."
    command git -C "${d:h}" pull -q --ff-only --recurse-submodules --autostash \
      || echo >&2 "  update failed for ${d:h:t}"
  done
  _plug_write_lock
}
```

- [ ] **Step 6: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: ZSH-08 assertions pass.

- [ ] **Step 7: Parse check** — `zsh -n config/zsh/rc.d/70-zsh-unplugged.zsh`. Expected: no output.

- [ ] **Step 8: Sanity — real clone still resolves the pin** — in an isolated dir, confirm the pinned checkout path works against the network (optional, requires connectivity):

Run:
```bash
ZPLUGIN_LOCK=config/zsh/plugins.lock ZDOTDIR=config/zsh zsh -dfc '
  source config/zsh/lib/platform.zsh; source config/zsh/rc.d/70-zsh-unplugged.zsh
  d=$(mktemp -d)/zsh-defer
  _plug_fetch romkatv/zsh-defer "$d"
  git -C "$d" rev-parse HEAD'
```
Expected: prints `53a26e287fbbe2dcebb3aa1801546c6de32416fa`. (Skip if offline; the fake-git test already covers logic.)

- [ ] **Step 9: Commit (deferred)** — `git add config/zsh/plugins.lock config/zsh/rc.d/70-zsh-unplugged.zsh tests/lib.sh tests/test-zsh.sh` (hold).

---

### Task 6: ZSH-06 — single fzf initialization

**Files:**
- Modify: `config/zsh/rc.d/71-plugins.zsh:13-21`
- Test: `tests/test-zsh.sh`

**Interfaces:**
- Consumes: `make_fake_bin` (Task 5), fake `git` pattern (Task 5).

- [ ] **Step 1: Write failing test** in `tests/test-zsh.sh`:

```bash
echo "== ZSH-06 fzf single init =="
fzf_dir="$tmp_runtime_root/fzfstub"
make_fake_bin "$fzf_dir" fzf '
if [ "$1" = "--zsh" ]; then echo "1" >> "$FZF_COUNT"; echo "# fzf init"; fi
exit 0'
# fake git so _plug_load calls in 71-plugins.zsh do not hit the network
git_dir="$tmp_runtime_root/gitstub2"
make_fake_bin "$git_dir" git '
if [ "$1" = "clone" ]; then dest="${@: -1}"; mkdir -p "$dest"; : > "$dest/x.plugin.zsh"; fi
exit 0'
fzf_count="$tmp_runtime_root/fzf_count"; : > "$fzf_count"
env -u KITTY_INSTALLATION_DIR HOME="$tmp_home" \
  XDG_CONFIG_HOME="$tmp_home/.config" XDG_DATA_HOME="$tmp_home/.local/share" \
  XDG_STATE_HOME="$tmp_home/.local/state" XDG_CACHE_HOME="$tmp_home/.cache" \
  FZF_COUNT="$fzf_count" ZPLUGINDIR="$tmp_runtime_root/fzfplug" \
  PATH="$fzf_dir:$git_dir:/usr/bin:/bin" zsh -dfc '
    source "$HOME/.zshenv"; source "$ZDOTDIR/lib/platform.zsh"
    source "$ZDOTDIR/rc.d/70-zsh-unplugged.zsh"
    source "$ZDOTDIR/rc.d/71-plugins.zsh"
  ' >/dev/null 2>&1
assert_eq "fzf --zsh is invoked exactly once" "1" "$(wc -l < "$fzf_count" | tr -d ' ')"
```

- [ ] **Step 2: Run to verify failure** — `bash tests/test-zsh.sh`. Expected: count is `2` (feature check + generation).

- [ ] **Step 3: Implement** — replace `config/zsh/rc.d/71-plugins.zsh` lines 13-21 with:

```zsh
## fzf - load immediately as it's frequently used
if command_exists fzf; then
  # Capture once, then source only when generation succeeded.
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n "$_fzf_init" ]]; then
    source <(print -r -- "$_fzf_init")
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
  unset _fzf_init
fi
```

- [ ] **Step 4: Run to verify pass** — `bash tests/test-zsh.sh`. Expected: `fzf --zsh is invoked exactly once` → `1`.

- [ ] **Step 5: Parse check** — `zsh -n config/zsh/rc.d/71-plugins.zsh`. Expected: no output.

- [ ] **Step 6: Commit (deferred)** — `git add config/zsh/rc.d/71-plugins.zsh tests/test-zsh.sh` (hold).

---

### Task 7: Full suite + review bookkeeping

**Files:**
- Modify: `docs/REVIEW-2026-07-14.md` (mark ZSH-04..09 Resolved)

- [ ] **Step 1: Run full test suite** — `make test`. Expected: all bootstrap, uninstall, and zsh suites pass; `FAIL` 0.

- [ ] **Step 2: Full parse check** — `zsh -n config/zsh/**/*.zsh config/zsh/zshenv`. Expected: no output.

- [ ] **Step 3: Shellcheck gate unchanged** — `make .lint-shell` (or the CI shell lint target). Expected: passes as before (no new bash files linted regressed).

- [ ] **Step 4: Mark findings Resolved** — in `docs/REVIEW-2026-07-14.md`, update ZSH-04, ZSH-05, ZSH-06, ZSH-07, ZSH-08, ZSH-09 to the resolved style used by ZSH-01..03 (add `— Resolved`, an `Original severity/status`, and a `Resolved: 2026-07-14 by <commit>` line — fill the commit hash when the user commits).

- [ ] **Step 5: Commit (deferred)** — `git add docs/REVIEW-2026-07-14.md` (hold; the whole change commits when the user asks).

## Self-Review

- **Spec coverage:** ZSH-04 (Task 2), ZSH-05 (Task 1), ZSH-06 (Task 6), ZSH-07 (Task 4), ZSH-08 (Task 5), ZSH-09 command_exists+dedup (Task 3) and dead-code removal (Tasks 4/5). Docs bookkeeping (Task 7). All spec sections mapped.
- **Placeholders:** none — every code and test step contains full content; the only deferred value is the commit hash in Task 7, unknowable until the user commits.
- **Type/name consistency:** `_plug_locked_rev`, `_plug_fetch`, `_plug_write_lock`, `_plug_update`, `_plug_clone`, `_plug_load`, `_plug_source`, `make_fake_bin`, `get_file_mtime_host`, `_compdump_stale`, `ZPLUGIN_LOCK` used consistently across tasks.
- **Ordering:** Task 5 introduces `make_fake_bin`; Task 6 reuses it. If executed out of order, Task 6 must include the `tests/lib.sh` helper from Task 5 Step 2 first.
