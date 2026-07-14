# https://github.com/mattmc3/zsh_unplugged (adapted)
# Minimal zsh plugin manager with a committed revision lock.

# _plug_lockfile: path to the revision manifest (overridable for tests).
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

# _plug_write_lock -> rewrite the lock from each clone's origin url + HEAD sha.
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
