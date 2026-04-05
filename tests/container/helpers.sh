#!/usr/bin/env bash
# helpers.sh — shared test utilities, sourced by each test script

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $label"
    ((PASS++)) || true
  else
    echo "  FAIL: $label"
    ((FAIL++)) || true
  fi
}

# check_cmd: verify a command exists and runs (exits 0)
check_cmd() {
  check "$1 exists" command -v "$1"
}

# check_file: verify a file exists
check_file() {
  check "file: $1" test -f "$1"
}

# check_dir: verify a directory exists
check_dir() {
  check "dir: $1" test -d "$1"
}

# check_contains: verify a file contains a string
check_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  check "$label" grep -q "$pattern" "$file"
}

# check_not_contains: verify a file does NOT contain a string
check_not_contains() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  FAIL: $label (found disallowed pattern: $pattern)"
    ((FAIL++)) || true
  else
    echo "  PASS: $label"
    ((PASS++)) || true
  fi
}

summary() {
  echo ""
  echo "Results: ${PASS} passed, ${FAIL} failed"
  [ "$FAIL" -eq 0 ]
}
