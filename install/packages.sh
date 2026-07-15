#!/usr/bin/env bash

# Declarative package manifest reader. All manifest parsing is isolated in
# _packages_awk; the rest consumes pipe-delimited records. Pure: no network,
# sudo, or filesystem mutation.

if [[ -z "${dot_title:-}" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

PACKAGES_CONF="${PACKAGES_CONF:-${dot_root:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/packages.conf}"

# Parse the grouped-tier manifest into `name|tiers|brew|cask|apt` records.
# Sections are cumulative ([minimal] packages belong to standard and full too),
# so a package's tiers are its section plus every higher tier. "-" columns
# become empty fields.
_packages_awk() {
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
        printf "packages: unknown section [%s] at line %d\n", s, NR > "/dev/stderr"
        section = ""
      }
      next
    }
    {
      if (section == "") {
        printf "packages: entry outside a tier section at line %d, skipped\n", NR > "/dev/stderr"
        next
      }
      if (NF != 4) {
        printf "packages: malformed entry at line %d (expected 4 columns, got %d), skipped\n", NR, NF > "/dev/stderr"
        next
      }
      brew = ($2 == "-") ? "" : $2
      cask = ($3 == "-") ? "" : $3
      apt  = ($4 == "-") ? "" : $4
      printf "%s|%s|%s|%s|%s\n", $1, tier[section], brew, cask, apt
    }
  ' "$1"
}

packages_records() {
  [[ -f "$PACKAGES_CONF" ]] || { dot_error "Package manifest not found: $PACKAGES_CONF"; return 1; }
  _packages_awk "$PACKAGES_CONF"
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
