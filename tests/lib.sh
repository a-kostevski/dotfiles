#!/usr/bin/env bash
# Shared test harness: pass/fail counters and assertions.
# Sourced by tests/test-*.sh after they set REPO_ROOT.

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (missing: $needle)"
  fi
}

# make_fake_bin <dir> <name> <body> — create an executable stub on a fake PATH.
make_fake_bin() {
  local dir="$1" name="$2" body="$3"
  mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$body"; } > "$dir/$name"
  chmod +x "$dir/$name"
}
