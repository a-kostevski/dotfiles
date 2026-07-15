#!/usr/bin/env bash

# Declarative manifest reader for dotfiles.
# Single source of source->destination truth. All manifest parsing is isolated
# in _manifest_awk; the rest of the codebase consumes the pipe-delimited records.

# Source shared library if not already loaded
if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

# Location of the declarative manifest (repo-relative by default). Distinct
# from MANIFEST_FILE, the runtime record of created symlinks (symlinks.sh).
MANIFEST_CONF="${MANIFEST_CONF:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/manifest.conf}"

# Parse the grouped-profile manifest into `name|kind|src|dest|profiles|platforms`
# records (one per entry). Sections are cumulative ([minimal] entries belong to
# standard and full too), so an entry's profiles are its section plus every
# higher tier. profiles/platforms are comma-joined with no spaces.
_manifest_awk() {
  awk '
    BEGIN {
      tier["minimal"]  = "minimal,standard,full"
      tier["standard"] = "standard,full"
      tier["full"]     = "full"
    }
    /^[[:space:]]*(#|$)/ { next }
    /^[[:space:]]*\[[a-z]+\][[:space:]]*$/ {
      s = $0
      gsub(/[^a-z]/, "", s)
      if (s in tier) { section = s } else {
        printf "manifest: unknown section [%s] at line %d\n", s, NR > "/dev/stderr"
        section = ""
      }
      next
    }
    {
      if (section == "") {
        printf "manifest: entry outside a profile section at line %d, skipped\n", NR > "/dev/stderr"
        next
      }
      if (NF < 4 || NF > 5) {
        printf "manifest: malformed entry at line %d (expected 4-5 columns, got %d), skipped\n", NR, NF > "/dev/stderr"
        next
      }
      platforms = (NF == 5) ? $5 : "all"
      printf "%s|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, tier[section], platforms
    }
  ' "$1"
}

# Print every manifest entry as name|kind|src|dest|profiles|platforms.
manifest_records() {
  [[ -f "$MANIFEST_CONF" ]] || { dot_error "Manifest not found: $MANIFEST_CONF"; return 1; }
  _manifest_awk "$MANIFEST_CONF"
}

# csv-membership test: does comma-list $2 contain exact token $1?
_manifest_csv_has() {
  local needle="$1" csv="$2" tok
  local IFS=,
  for tok in $csv; do [[ "$tok" == "$needle" ]] && return 0; done
  return 1
}

# Filter entries to a profile + OS. `all` profile matches every entry.
manifest_select() {
  local profile="$1" os="$2"
  local name kind src dest profiles platforms
  while IFS='|' read -r name kind src dest profiles platforms; do
    [[ -z "$name" ]] && continue
    _manifest_csv_has "all" "$platforms" || _manifest_csv_has "$os" "$platforms" || continue
    if [[ "$profile" != "all" ]]; then
      _manifest_csv_has "$profile" "$profiles" || continue
    fi
    printf '%s|%s|%s|%s|%s|%s\n' "$name" "$kind" "$src" "$dest" "$profiles" "$platforms"
  done < <(manifest_records)
}

# Resolve destination placeholders against the environment.
_manifest_resolve_dest() {
  local d="$1"
  d="${d//\{XDG_CONFIG\}/$HOME/.config}"
  d="${d//\{HOME\}/$HOME}"
  d="${d//\{BIN\}/$HOME/.local/bin}"
  printf '%s' "$d"
}

# Absolute srcs of file-kind entries in the given selected record set (stdin).
# Used to shadow those files out of their containing tree.
_manifest_shadow_srcs() {
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ "$kind" == "file" ]] || continue
    printf '%s\n' "${dot_root}/${src}"
  done
}

# Expand one entry to src|dest pairs. $4 is a newline list of shadowed abs srcs.
_manifest_emit() {
  local kind="$1" src="$2" dest="$3" shadow="$4"
  local abs_src="${dot_root}/${src}"
  local res_dest; res_dest="$(_manifest_resolve_dest "$dest")"

  if [[ "$kind" == "file" ]]; then
    if [[ -f "$abs_src" ]]; then
      printf '%s|%s\n' "$abs_src" "$res_dest"
    else
      dot_warning "manifest: src not found: $src" >&2
    fi
    return 0
  fi

  if [[ ! -d "$abs_src" ]]; then
    dot_warning "manifest: src not found: $src" >&2
    return 0
  fi

  local f rel
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    is_ignored "$f" && continue
    if [[ -n "$shadow" ]] && grep -qxF "$f" <<<"$shadow"; then
      continue
    fi
    rel="${f#"$abs_src"/}"
    printf '%s|%s\n' "$f" "$res_dest/$rel"
  done < <(find "$abs_src" -type f 2>/dev/null | sort)
}

# THE single source of link truth: src|dest pairs for a profile + OS.
manifest_links() {
  local profile="$1" os="$2"
  local selected; selected="$(manifest_select "$profile" "$os")"
  local shadow; shadow="$(_manifest_shadow_srcs <<<"$selected")"
  local name kind src dest rest
  while IFS='|' read -r name kind src dest rest; do
    [[ -z "$name" ]] && continue
    _manifest_emit "$kind" "$src" "$dest" "$shadow"
  done <<<"$selected"
}

# Print the component that owns a repo-relative src: the name of a tree entry
# whose src is a path-prefix of $1, else $1's own entry name.
manifest_component_of() {
  local target="$1"
  local name kind src rest owner=""
  while IFS='|' read -r name kind src rest; do
    [[ -z "$name" ]] && continue
    if [[ "$kind" == "tree" && ( "$target" == "$src" || "$target" == "$src"/* ) ]]; then
      owner="$name"
    fi
  done < <(manifest_records)
  printf '%s' "$owner"
}

# Component names for a profile + OS. A file entry contained in a tree entry's
# src is folded into that tree's component (no standalone header).
manifest_components() {
  local profile="$1" os="$2"
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ -z "$name" ]] && continue
    if [[ "$kind" == "file" ]]; then
      local owner; owner="$(manifest_component_of "$src")"
      [[ -n "$owner" ]] && continue   # folded into its tree component
    fi
    printf '%s\n' "$name"
  done < <(manifest_select "$profile" "$os")
}

# src|dest pairs for a single component (unfiltered by profile): the entry named
# <name> plus any file entry whose src is contained in that entry's tree src.
manifest_component_links() {
  local component="$1" os="$2"
  local name kind src dest profiles platforms
  local -a picked=()
  while IFS='|' read -r name kind src dest profiles platforms; do
    [[ -z "$name" ]] && continue
    # OS gate: only pick entries selectable on the given platform.
    _manifest_csv_has "all" "$platforms" || _manifest_csv_has "$os" "$platforms" || continue
    if [[ "$name" == "$component" ]]; then
      picked+=("$name|$kind|$src|$dest")
    elif [[ "$kind" == "file" ]]; then
      local owner; owner="$(manifest_component_of "$src")"
      [[ "$owner" == "$component" ]] && picked+=("$name|$kind|$src|$dest")
    fi
  done < <(manifest_records)

  local kind2 src2 dest2
  local shadow=""
  # build shadow set from the picked (OS-gated) file entries
  local p
  for p in "${picked[@]}"; do
    IFS='|' read -r _ kind2 src2 dest2 <<<"$p"
    [[ "$kind2" == "file" ]] && shadow+="${dot_root}/${src2}"$'\n'
  done
  for p in "${picked[@]}"; do
    IFS='|' read -r _ kind2 src2 dest2 <<<"$p"
    _manifest_emit "$kind2" "$src2" "$dest2" "$shadow"
  done
}

# 0 if <name> is a component (a top-level entry name that is not a file folded
# into another tree) whose source exists.
manifest_component_exists() {
  local component="$1"
  local name kind src rest
  while IFS='|' read -r name kind src rest; do
    [[ "$name" == "$component" ]] || continue
    [[ -e "${dot_root}/${src}" ]] && return 0
    return 1
  done < <(manifest_records)
  return 1
}

# Resolved dests of file entries that live outside {XDG_CONFIG} and {BIN}
# (i.e. home-directory targets like ~/.zshenv), OS-gated. Used by uninstall.
manifest_home_dests() {
  local os="$1"
  local name kind src dest profiles platforms res
  while IFS='|' read -r name kind src dest profiles platforms; do
    [[ -z "$name" ]] && continue
    [[ "$kind" == "file" ]] || continue
    [[ "$dest" == '{XDG_CONFIG}'* || "$dest" == '{BIN}'* ]] && continue
    _manifest_csv_has "all" "$platforms" || _manifest_csv_has "$os" "$platforms" || continue
    res="$(_manifest_resolve_dest "$dest")"
    printf '%s\n' "$res"
  done < <(manifest_records)
}

# Validate a profile name. `custom` is no longer supported.
validate_profile() {
  case "$1" in
    minimal | standard | full | all) return 0 ;;
    *)
      dot_error "Invalid profile: $1"
      dot_error "Valid profiles: minimal, standard, full, all"
      return 1
      ;;
  esac
}

get_profile_description() {
  case "$1" in
    minimal) echo "Essential configs only (git, zsh, tmux)" ;;
    standard) echo "Common development tools (minimal + nvim, bat, python)" ;;
    full) echo "Everything including GUI apps" ;;
    all) echo "All available configs in the manifest" ;;
    *) echo "Unknown profile" ;;
  esac
}
