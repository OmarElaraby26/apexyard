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
    cd "$sb"
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
run_case "gh issue close 42 (chore exempt) → ALLOW" \
  "gh issue close 42" "chore" 0
run_case "gh issue close 42 (qa-bypass exempt) → ALLOW" \
  "gh issue close 42" "qa-bypass" 0
run_case "gh issue close 42 (feature, not exempt) → BLOCK" \
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
