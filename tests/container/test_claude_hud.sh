#!/usr/bin/env bash
# test_claude_hud.sh — verify the trimmed claude-hud statusline binary
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== claude-hud: binary exists and runs ==="

check_cmd claude-hud

# Without stdin, claude-hud prints an init banner and exits 0.
check "no-stdin path exits 0" claude-hud

echo "=== claude-hud: renders minimal stdin ==="

# Build a minimal stdin payload.
read -r -d '' STDIN <<'JSON' || true
{"transcript_path":"","cwd":"/tmp","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON

OUTPUT=$(printf '%s' "$STDIN" | claude-hud 2>&1)
RC=$?

if [[ $RC -ne 0 ]]; then
  echo "  FAIL: claude-hud exited $RC on minimal stdin"
  ((FAIL++)) || true
else
  echo "  PASS: claude-hud exits 0 on minimal stdin"
  ((PASS++)) || true
fi

if [[ -z "$OUTPUT" ]]; then
  echo "  FAIL: claude-hud produced no output"
  ((FAIL++)) || true
else
  echo "  PASS: claude-hud produced output"
  ((PASS++)) || true
fi

if echo "$OUTPUT" | grep -q "Sonnet"; then
  echo "  PASS: output contains model name"
  ((PASS++)) || true
else
  echo "  FAIL: output missing model name"
  ((FAIL++)) || true
fi

echo "=== claude-hud: handles non-git cwd without crashing ==="

NON_GIT_CWD=$(mktemp -d)
read -r -d '' STDIN_NOGIT <<JSON || true
{"transcript_path":"","cwd":"$NON_GIT_CWD","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON
printf '%s' "$STDIN_NOGIT" | claude-hud >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "  PASS: handles non-git cwd"
  ((PASS++)) || true
else
  echo "  FAIL: crashed on non-git cwd"
  ((FAIL++)) || true
fi
rm -rf "$NON_GIT_CWD"

echo "=== claude-hud: handles missing transcript path ==="

# transcript_path = "" already covered above; also test when it's set but bogus.
read -r -d '' STDIN_BADXP <<JSON || true
{"transcript_path":"/nonexistent/path.jsonl","cwd":"/tmp","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON
printf '%s' "$STDIN_BADXP" | claude-hud >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "  PASS: handles missing transcript path"
  ((PASS++)) || true
else
  echo "  FAIL: crashed on missing transcript path"
  ((FAIL++)) || true
fi

summary
