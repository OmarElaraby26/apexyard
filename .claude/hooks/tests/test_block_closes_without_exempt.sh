#!/bin/bash
# Tests for block-closes-without-exempt-label.sh

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/block-closes-without-exempt-label.sh"
LIB_RC="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"
DEFAULTS="$SRC_ROOT/.claude/project-config.defaults.json"

for f in "$HOOK_SRC" "$LIB_RC" "$DEFAULTS"; do
  [ -f "$f" ] || { echo "FAIL: required source missing: $f" >&2; exit 1; }
done

source "$(dirname "$0")/_lib-mock-gh.sh"

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
  mkdir -p "$sb/.claude/hooks" "$sb/bin"
  cp "$HOOK_SRC" "$sb/.claude/hooks/"
  cp "$LIB_RC"   "$sb/.claude/hooks/"
  mkdir -p "$sb/.claude/"
  cp "$DEFAULTS" "$sb/.claude/"
  echo "$sb"
}

# Set issue labels via a label-stub in the mock gh (overrides default).
install_label_stub() {
  local sb="$1"
  # Write a labels file the stub reads: "<num> <comma-separated labels>"
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
  if [ -f "\$LABELS_FILE" ]; then
    labels=\$(grep -E "^\${num} " "\$LABELS_FILE" | tail -1 | cut -d' ' -f2-)
  fi
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
  PATH="$sb/bin:$PATH"
  export PATH
}

set_labels() {
  local sb="$1" num="$2" labels="$3"
  echo "$num $labels" >> "$sb/.mock-gh-labels"
}

run_case() {
  local desc="$1" body="$2" labels_for_42="$3" expect_exit="$4"
  local sb
  sb=$(make_sandbox)
  install_label_stub "$sb"
  if [ -n "$labels_for_42" ]; then
    set_labels "$sb" 42 "$labels_for_42"
  fi

  local input
  input=$(jq -n --arg cmd "gh pr create --title 'feat(#42): test' --body \"$body\"" \
    '{tool_input: {command: $cmd}}')
  local exit_code=0
  (cd "$sb" && echo "$input" | bash .claude/hooks/block-closes-without-exempt-label.sh) >/dev/null 2>&1 || exit_code=$?

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

echo "block-closes-without-exempt-label.sh tests"
echo "---"
# Narrow exempt set: qa-bypass is the ONLY exempt label (AgDR-0032).
# chore / docs / spike / infra used to be exempt under AgDR-0031; they
# now flow through QA like everything else.

# Case: Closes on issue with no labels → BLOCK
run_case "Closes #42 on issue with no labels → BLOCK" \
  "Closes #42" "" 2
# Case: Refs (no Closes) → ALLOW (no autoclose form)
run_case "Refs #42 on non-exempt → ALLOW (no autoclose keyword)" \
  "Refs #42" "" 0
# Case: Fixes synonym → BLOCK
run_case "Fixes #42 on non-exempt → BLOCK" \
  "Fixes #42" "" 2
# Case: Resolves synonym → BLOCK
run_case "Resolves #42 on non-exempt → BLOCK" \
  "Resolves #42" "" 2

# Narrow-set regressions (post AgDR-0032): chore / docs / spike / infra
# are NO LONGER exempt and must BLOCK.
run_case "Closes #42 on chore-labeled → BLOCK (chore no longer exempt)" \
  "Closes #42" "chore" 2
run_case "Closes #42 on docs-labeled → BLOCK (docs no longer exempt)" \
  "Closes #42" "docs" 2
run_case "Closes #42 on spike-labeled → BLOCK (spike no longer exempt)" \
  "Closes #42" "spike" 2
run_case "Closes #42 on infra-labeled → BLOCK (infra no longer exempt)" \
  "Closes #42" "infra" 2

# qa-bypass remains the sole exempt label.
run_case "Closes #42 on qa-bypass-labeled → ALLOW (sole exempt label)" \
  "Closes #42" "qa-bypass" 0

# Case: feature-labeled (never exempt) → BLOCK
run_case "Closes #42 on feature-labeled → BLOCK" \
  "Closes #42" "feature" 2

echo "---"
echo "Total: PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed:\n%b' "$FAILED"
  exit 1
fi
exit 0
