#!/bin/bash
# Tests for block-merge-on-red-ci.sh — exercises the .ci.require_to_exist
# config flag added under #5 (OmarElaraby26/apexyard) for free-tier
# private repos that need strict missing-CI = blocked behaviour.
#
# Cases:
#   1. no checks + flag absent       → exit 0 (legacy NOTE pass)
#   2. no checks + flag false        → exit 0 (explicit-default pass)
#   3. no checks + flag true         → exit 2 (strict block)
#   4. all-green + flag true         → exit 0 (green still passes)
#   5. red CI + flag true            → exit 2 (red still blocks regardless of flag)
#   6. red CI + flag absent          → exit 2 (legacy red-block path)
#
# Exit 0 if all cases pass; 1 on first failure.

set -u

SRC_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK_SRC="$SRC_ROOT/.claude/hooks/block-merge-on-red-ci.sh"
LIB_PR="$SRC_ROOT/.claude/hooks/_lib-extract-pr.sh"
LIB_CFG="$SRC_ROOT/.claude/hooks/_lib-read-config.sh"
DEFAULTS_SRC="$SRC_ROOT/.claude/project-config.defaults.json"

for f in "$HOOK_SRC" "$LIB_PR" "$LIB_CFG" "$DEFAULTS_SRC"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source missing: $f" >&2
    exit 1
  fi
done

PASS=0
FAIL=0
FAILED_CASES=""

make_sandbox() {
  local sb
  sb=$(mktemp -d)
  (
    cd "$sb" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    : > onboarding.yaml
    git add onboarding.yaml
    git commit -q -m "init"
  )
  mkdir -p "$sb/.claude/hooks" "$sb/.claude" "$sb/bin"
  cp "$HOOK_SRC"     "$sb/.claude/hooks/block-merge-on-red-ci.sh"
  cp "$LIB_PR"       "$sb/.claude/hooks/_lib-extract-pr.sh"
  cp "$LIB_CFG"      "$sb/.claude/hooks/_lib-read-config.sh"
  cp "$DEFAULTS_SRC" "$sb/.claude/project-config.defaults.json"
  chmod +x "$sb/.claude/hooks/block-merge-on-red-ci.sh"
  echo "$sb"
}

# Install a `gh` mock whose `gh pr checks <N>` output is the second arg.
# Exit code is the third arg. All other gh invocations are no-op pass.
install_gh_mock() {
  local sb="$1"
  local checks_stdout="$2"
  local checks_rc="$3"
  cat > "$sb/bin/gh" <<EOF
#!/bin/bash
case "\$*" in
  *"pr checks"*)
    cat <<'CHECKS'
$checks_stdout
CHECKS
    exit $checks_rc
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$sb/bin/gh"
}

# Write an override config setting .ci.require_to_exist
write_override() {
  local sb="$1" val="$2"
  cat > "$sb/.claude/project-config.json" <<EOF
{
  "ci": { "require_to_exist": ${val} }
}
EOF
}

run_case() {
  local name="$1" sb="$2" want_rc="$3" want_stderr_re="$4"
  local input='{"tool_input":{"command":"gh pr merge 42 --repo owner/repo --squash"}}'
  local stderr_out exit_code
  stderr_out=$(cd "$sb" && PATH="$sb/bin:$PATH" \
    bash .claude/hooks/block-merge-on-red-ci.sh <<<"$input" 2>&1 >/dev/null)
  exit_code=$?
  if [ "$exit_code" != "$want_rc" ]; then
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - ${name}: want exit ${want_rc}, got ${exit_code}\n    stderr: ${stderr_out}"
    return
  fi
  if [ -n "$want_stderr_re" ] && ! echo "$stderr_out" | grep -qE "$want_stderr_re"; then
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - ${name}: stderr did not match /${want_stderr_re}/\n    stderr: ${stderr_out}"
    return
  fi
  PASS=$((PASS + 1))
}

# --- Case 1: no checks + flag absent → exit 0 ---
sb=$(make_sandbox)
install_gh_mock "$sb" "no checks reported on the 'feature/x' branch" 0
run_case "no-checks-flag-absent" "$sb" 0 "no CI checks configured"
rm -rf "$sb"

# --- Case 2: no checks + flag false → exit 0 ---
sb=$(make_sandbox)
install_gh_mock "$sb" "no checks reported on the 'feature/x' branch" 0
write_override "$sb" "false"
run_case "no-checks-flag-false" "$sb" 0 "no CI checks configured"
rm -rf "$sb"

# --- Case 3: no checks + flag true → exit 2 ---
sb=$(make_sandbox)
install_gh_mock "$sb" "no checks reported on the 'feature/x' branch" 0
write_override "$sb" "true"
run_case "no-checks-flag-true" "$sb" 2 "no CI checks reported"
rm -rf "$sb"

# --- Case 4: all-green + flag true → exit 0 ---
sb=$(make_sandbox)
install_gh_mock "$sb" "ok  build  Lint" 0
write_override "$sb" "true"
run_case "green-flag-true" "$sb" 0 ""
rm -rf "$sb"

# --- Case 5: red CI + flag true → exit 2 ---
sb=$(make_sandbox)
install_gh_mock "$sb" "fail  build  Lint" 1
write_override "$sb" "true"
run_case "red-flag-true" "$sb" 2 "red CI"
rm -rf "$sb"

# --- Case 6: red CI + flag absent → exit 2 (legacy) ---
sb=$(make_sandbox)
install_gh_mock "$sb" "fail  build  Lint" 1
run_case "red-flag-absent" "$sb" 2 "red CI"
rm -rf "$sb"

echo "----------------------------------------"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '%b\n' "Failed cases:$FAILED_CASES"
  exit 1
fi
exit 0
