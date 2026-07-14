#!/usr/bin/env bash

# Declarative package manifest reader. All TOML parsing is isolated in
# _packages_awk; the rest consumes pipe-delimited records. Pure: no network,
# sudo, or filesystem mutation.

if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

PACKAGES_TOML="${PACKAGES_TOML:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/install/packages.toml}"

_packages_awk() {
  awk '
    function flush() {
      if (have) printf "%s|%s|%s|%s|%s\n", p["name"], p["tiers"], p["brew"], p["cask"], p["apt"]
      have = 0; delete p
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[\[package\]\]/ { flush(); have = 1; next }
    /^[[:space:]]*[a-z][a-z-]*[[:space:]]*=/ {
      key = $1
      eq = index($0, "="); val = substr($0, eq + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if (val ~ /^\[/) { gsub(/^\[|\]$/, "", val); gsub(/"/, "", val); gsub(/[[:space:]]+/, "", val) }
      else { gsub(/^"|"$/, "", val) }
      p[key] = val; have = 1; next
    }
    END { flush() }
  ' "$1"
}

packages_records() {
  [[ -f "$PACKAGES_TOML" ]] || { dot_error "Package manifest not found: $PACKAGES_TOML"; return 1; }
  _packages_awk "$PACKAGES_TOML"
}

_packages_csv_has() {
  local needle="$1" csv="$2" tok
  local IFS=,
  for tok in $csv; do [[ "$tok" == "$needle" ]] && return 0; done
  return 1
}

# packages_select <tier> <field>   field ∈ brew|cask|apt
packages_select() {
  local tier="$1" field="$2"
  local name tiers brew cask apt val
  while IFS='|' read -r name tiers brew cask apt; do
    [[ -z "$name" ]] && continue
    _packages_csv_has "$tier" "$tiers" || continue
    case "$field" in
      brew) val="$brew" ;;
      cask) val="$cask" ;;
      apt) val="$apt" ;;
      *) continue ;;
    esac
    [[ -n "$val" ]] && printf '%s\n' "$val"
  done < <(packages_records)
}

validate_tier() {
  case "$1" in
    minimal | standard | full) return 0 ;;
    *)
      dot_error "Invalid package tier: $1"
      dot_error "Valid tiers: minimal, standard, full"
      return 1
      ;;
  esac
}

# resolve_package_tier <profile> [override]
resolve_package_tier() {
  local profile="$1" override="${2:-}" tier
  if [[ -n "$override" ]]; then
    tier="$override"
  else
    case "$profile" in
      minimal) tier="minimal" ;;
      standard) tier="standard" ;;
      full | all) tier="full" ;;
      *) tier="minimal" ;;
    esac
  fi
  validate_tier "$tier" || return 1
  printf '%s' "$tier"
}
