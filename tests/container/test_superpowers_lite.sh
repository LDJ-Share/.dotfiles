#!/usr/bin/env bash
# test_superpowers_lite.sh — verify the vendored Claude Code skills are
# present and well-formed in the container.
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

EXPECTED_SKILLS=(
  using-superpowers
  brainstorming
  writing-plans
  executing-plans
  subagent-driven-development
  using-git-worktrees
  verification-before-completion
  requesting-code-review
  finishing-a-development-branch
  tiered-subagent-dispatch
  final-branch-review
  verifying-subagent-output
  iterative-review-before-commit
  dotnet-style-workflow
)

HARD_GATE_SKILLS=(
  brainstorming
  writing-plans
)

echo "=== superpowers-lite: skill directories exist ==="

check_dir "${SKILLS_DIR}"

for s in "${EXPECTED_SKILLS[@]}"; do
  check_dir "${SKILLS_DIR}/${s}"
  check_file "${SKILLS_DIR}/${s}/SKILL.md"
done

echo "=== superpowers-lite: SKILL.md frontmatter ==="

for s in "${EXPECTED_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  if [[ ! -f "$f" ]]; then
    continue
  fi
  check "$s frontmatter opens with ---" bash -c "head -1 '$f' | grep -q '^---$'"
  check_contains "$s has name field" "$f" "^name:"
  check_contains "$s has description field" "$f" "^description:"
done

echo "=== superpowers-lite: design-chain hard-gate markers ==="

for s in "${HARD_GATE_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  check_contains "$s has hard-gate marker" "$f" "Next step (required)"
done

echo "=== superpowers-lite: SKILL.md length budget ==="

for s in "${EXPECTED_SKILLS[@]}"; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  if [[ ! -f "$f" ]]; then
    continue
  fi
  lines=$(wc -l < "$f")
  if [[ "$lines" -le 100 ]]; then
    echo "  PASS: $s SKILL.md is $lines lines (<=100)"
    ((PASS++)) || true
  else
    echo "  WARN: $s SKILL.md is $lines lines (>100 - soft fail; investigate)"
  fi
done

echo "=== superpowers-lite: container-only CLAUDE.md ==="

check_file "${CLAUDE_MD}"
check_contains "CLAUDE.md mentions universal disciplines" "${CLAUDE_MD}" "Universal disciplines"

echo "=== superpowers-lite: stow package structure ==="

# In the container, ~/.claude is already populated by Dockerfile COPY layers,
# so stow dry-run against the live target would report conflicts. Validate the
# package structure against a clean tmp target instead — this confirms .stowrc
# and skills/ are stow-compatible for host deploy without colliding with the
# container's COPY layout.
if [[ -d "${HOME}/.dotfiles/dot-claude" ]]; then
  TMP_TARGET=$(mktemp -d)
  if stow -nv -d "${HOME}/.dotfiles" -t "${TMP_TARGET}" dot-claude >/dev/null 2>&1; then
    echo "  PASS: stow package validates against clean target"
    ((PASS++)) || true
  else
    echo "  FAIL: stow package reports conflicts even against clean target"
    ((FAIL++)) || true
  fi
  rmdir "${TMP_TARGET}" 2>/dev/null || true
else
  echo "  SKIP: dotfiles not present at ~/.dotfiles"
fi

summary
