#!/bin/bash
# Tests for block-issue-close-without-qa-passed.sh

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/block-issue-close-without-qa-passed.sh"
LIB_RC="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"
DEFAULTS="$SRC_ROOT/.claude/project-config.defaults.json"

for f in "$HOOK_SRC" "$LIB_RC" "$DEFAULTS"; do
  [ -f "$f" ] || { echo "FAIL: required source missing: $f" >&2; exit 1; }
done

PASS=0
FAIL=0
FAILED=""

make_sandbox() {
  local sb
  sb=$(mktemp -d)
  (
    cd "$sb" || exit
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    git remote add origin https://github.com/fake-org/fake-repo.git
    : > onboarding.yaml
    : > apexyard.projects.yaml
    git add onboarding.yaml apexyard.projects.yaml
    git commit -q -m init
  )
  mkdir -p "$sb/.claude/hooks" "$sb/bin" "$sb/.claude/"
  cp "$HOOK_SRC" "$sb/.claude/hooks/"
  cp "$LIB_RC"   "$sb/.claude/hooks/"
  cp "$DEFAULTS" "$sb/.claude/"
  : > "$sb/.mock-gh-labels"
  cat > "$sb/bin/gh" <<EOF
#!/bin/bash
LABELS_FILE="$sb/.mock-gh-labels"
if [ "\$1" = "issue" ] && [ "\$2" = "view" ]; then
  num="\$3"
  jq_filter=""
  shift 3
  while [ \$# -gt 0 ]; do
    case "\$1" in
      --jq) jq_filter="\$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  labels=\$(grep -E "^\${num} " "\$LABELS_FILE" | tail -1 | cut -d' ' -f2-)
  if [ -z "\$labels" ]; then
    json='{"labels":[]}'
  else
    json_labels=\$(echo "\$labels" | tr ',' '\n' | sed 's/.*/{"name":"&"}/' | paste -sd, -)
    json="{\"labels\":[\$json_labels]}"
  fi
  if [ -n "\$jq_filter" ]; then
    echo "\$json" | jq -r "\$jq_filter"
  else
    echo "\$json"
  fi
  exit 0
fi
exit 0
EOF
  chmod +x "$sb/bin/gh"
  echo "$sb"
}

run_case() {
  local desc="$1" cmd="$2" labels_for_42="$3" expect_exit="$4"
  local sb
  sb=$(make_sandbox)
  if [ -n "$labels_for_42" ]; then
    echo "42 $labels_for_42" >> "$sb/.mock-gh-labels"
  fi
  local input
  input=$(jq -n --arg cmd "$cmd" '{tool_input: {command: $cmd}}')

  local saved_path="$PATH"
  PATH="$sb/bin:$PATH"
  local exit_code=0
  (cd "$sb" && echo "$input" | bash .claude/hooks/block-issue-close-without-qa-passed.sh) >/dev/null 2>&1 || exit_code=$?
  PATH="$saved_path"

  if [ "$exit_code" = "$expect_exit" ]; then
    PASS=$((PASS+1))
    printf '  PASS: %s (exit=%s)\n' "$desc" "$exit_code"
  else
    FAIL=$((FAIL+1))
    FAILED="${FAILED}    - ${desc} (expected ${expect_exit}, got ${exit_code})\n"
    printf '  FAIL: %s (expected exit=%s, got %s)\n' "$desc" "$expect_exit" "$exit_code"
  fi
  rm -rf "$sb"
}

echo "block-issue-close-without-qa-passed.sh tests"
echo "---"
# gh issue close <N>
run_case "gh issue close 42 (no labels) → BLOCK" \
  "gh issue close 42" "" 2
run_case "gh issue close 42 (qa-passed) → ALLOW" \
  "gh issue close 42" "qa-passed" 0
# Narrow exempt set (AgDR-0032): qa-bypass is the ONLY exempt label.
# chore / docs / spike / infra are NO LONGER exempt — they BLOCK without qa-passed.
run_case "gh issue close 42 (chore — no longer exempt) → BLOCK" \
  "gh issue close 42" "chore" 2
run_case "gh issue close 42 (docs — no longer exempt) → BLOCK" \
  "gh issue close 42" "docs" 2
run_case "gh issue close 42 (spike — no longer exempt) → BLOCK" \
  "gh issue close 42" "spike" 2
run_case "gh issue close 42 (infra — no longer exempt) → BLOCK" \
  "gh issue close 42" "infra" 2
run_case "gh issue close 42 (qa-bypass — sole exempt) → ALLOW" \
  "gh issue close 42" "qa-bypass" 0
run_case "gh issue close 42 (feature, never exempt) → BLOCK" \
  "gh issue close 42" "feature" 2

# gh issue edit <N> --state closed
run_case "gh issue edit 42 --state closed (no labels) → BLOCK" \
  "gh issue edit 42 --state closed" "" 2
run_case "gh issue edit 42 --state closed --add-label qa-passed → ALLOW (atomic)" \
  "gh issue edit 42 --state closed --add-label qa-passed" "" 0

# gh api repos/.../issues/<N> state=closed
run_case "gh api repos/o/r/issues/42 -f state=closed (no labels) → BLOCK" \
  "gh api repos/o/r/issues/42 -X PATCH -f state=closed" "" 2
run_case "gh api repos/o/r/issues/42 -f state=closed (qa-passed) → ALLOW" \
  "gh api repos/o/r/issues/42 -X PATCH -f state=closed" "qa-passed" 0

# Regression: --add-label qa-passed-but-not-really must NOT match
# (was a word-boundary bypass — qa-passed-suffix could trick the atomic
# verify+close detection)
run_case "atomic-close regex must NOT match qa-passed-but-not-really → BLOCK" \
  "gh issue close 42 --add-label qa-passed-but-not-really" "" 2
run_case "atomic-close regex still matches qa-passed exact → ALLOW" \
  "gh issue close 42 --add-label qa-passed" "" 0
run_case "atomic-close regex matches qa-passed,chore (label list) → ALLOW" \
  "gh issue close 42 --add-label qa-passed,chore" "" 0

# Regression: multi-number `gh issue edit N1 N2 N3 --state closed` must
# check EVERY number, not just the first. Need a custom test runner that
# sets labels on multiple issues.
run_multi_case() {
  local desc="$1" cmd="$2" labels_42="$3" labels_43="$4" expect_exit="$5"
  local sb
  sb=$(make_sandbox)
  [ -n "$labels_42" ] && echo "42 $labels_42" >> "$sb/.mock-gh-labels"
  [ -n "$labels_43" ] && echo "43 $labels_43" >> "$sb/.mock-gh-labels"
  local input
  input=$(jq -n --arg cmd "$cmd" '{tool_input: {command: $cmd}}')
  local saved_path="$PATH"
  PATH="$sb/bin:$PATH"
  local exit_code=0
  (cd "$sb" && echo "$input" | bash .claude/hooks/block-issue-close-without-qa-passed.sh) >/dev/null 2>&1 || exit_code=$?
  PATH="$saved_path"
  if [ "$exit_code" = "$expect_exit" ]; then
    PASS=$((PASS+1))
    printf '  PASS: %s (exit=%s)\n' "$desc" "$exit_code"
  else
    FAIL=$((FAIL+1))
    FAILED="${FAILED}    - ${desc} (expected ${expect_exit}, got ${exit_code})\n"
    printf '  FAIL: %s (expected exit=%s, got %s)\n' "$desc" "$expect_exit" "$exit_code"
  fi
  rm -rf "$sb"
}
run_multi_case "multi-num edit — 42=qa-passed, 43=none → BLOCK on 43" \
  "gh issue edit 42 43 --state closed" "qa-passed" "" 2
run_multi_case "multi-num edit — both qa-passed → ALLOW" \
  "gh issue edit 42 43 --state closed" "qa-passed" "qa-passed" 0
run_multi_case "multi-num edit — 42=qa-bypass, 43=qa-passed → ALLOW (mixed exempt+verified)" \
  "gh issue edit 42 43 --state closed" "qa-bypass" "qa-passed" 0
run_multi_case "multi-num edit — 42=chore (no longer exempt), 43=qa-passed → BLOCK on 42" \
  "gh issue edit 42 43 --state closed" "chore" "qa-passed" 2

# Unrelated commands → no-op
run_case "gh issue view 42 → no-op (not a close)" \
  "gh issue view 42" "" 0
run_case "gh pr view 42 → no-op" \
  "gh pr view 42" "" 0

echo "---"
echo "Total: PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed:\n%b' "$FAILED"
  exit 1
fi
exit 0
