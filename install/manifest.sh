#!/usr/bin/env bash

# Declarative manifest reader for dotfiles.
# Single source of source->destination truth. All TOML parsing is isolated in
# _manifest_awk; the rest of the codebase consumes the pipe-delimited records.

# Source shared library if not already loaded
if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

# Location of the declarative manifest (repo-relative by default)
MANIFEST_TOML="${MANIFEST_TOML:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/install/manifest.toml}"

# Parse the constrained TOML subset into `name|kind|src|dest|profiles|platforms`
# records (one per entry). profiles/platforms are comma-joined with no spaces.
_manifest_awk() {
  awk '
    function flush() {
      if (have) printf "%s|%s|%s|%s|%s|%s\n", \
        e["name"], e["kind"], e["src"], e["dest"], e["profiles"], e["platforms"]
      have = 0; delete e
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[\[entry\]\]/ { flush(); have = 1; next }
    /^[[:space:]]*[a-z][a-z-]*[[:space:]]*=/ {
      key = $1
      eq = index($0, "=")
      val = substr($0, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if (val ~ /^\[/) {
        gsub(/^\[|\]$/, "", val); gsub(/"/, "", val); gsub(/[[:space:]]+/, "", val)
      } else {
        gsub(/^"|"$/, "", val)
      }
      e[key] = val; have = 1; next
    }
    END { flush() }
  ' "$1"
}

# Print every manifest entry as name|kind|src|dest|profiles|platforms.
manifest_records() {
  [[ -f "$MANIFEST_TOML" ]] || { dot_error "Manifest not found: $MANIFEST_TOML"; return 1; }
  _manifest_awk "$MANIFEST_TOML"
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
