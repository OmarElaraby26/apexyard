#!/bin/bash
# PreToolUse hook on `gh pr create`: blocks the PR if the body contains an
# auto-close keyword (Closes / Fixes / Resolves followed by #N) and the
# referenced issue does NOT have one of the exempt labels.
#
# Forces production-class tickets to use `Refs #N` so they route through the
# QA gate (workflows/sdlc.md § Phase 5) after merge instead of auto-closing
# and bypassing Salim (QA Engineer).
#
# Exempt labels (allow auto-close):
#   - chore | docs | spike | infra | qa-bypass
#
# Exit codes:
#   0 = allowed (no auto-close keyword, every referenced issue is exempt,
#       repo is unresolvable, or no body to parse)
#   2 = blocked (auto-close on a production-class issue without exempt label)
#
# Pairs with:
#   - block-issue-close-without-qa-passed.sh (close-time gate)
#   - golden-paths/pipelines/move-to-qa-on-merge.yml (server-side routing)
#   - golden-paths/pipelines/qa-gate.yml (server-side safety net)
#
# Config (read via _lib-read-config.sh):
#   .qa.exempt_labels[]       → label list that allows auto-close
#   .qa.autoclose_keywords[]  → keywords that trigger the gate (default Closes|Fixes|Resolves)
# Both have defaults in .claude/project-config.defaults.json; override via
# .claude/project-config.json shallow-merge.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Match only `gh pr create …`.
if ! echo "$COMMAND" | grep -qE '\bgh\s+pr\s+create\b'; then
  exit 0
fi

# Extract --body / --body-file / -F (matches the parser shape in
# require-agdr-for-arch-pr.sh — short-flag value extraction).
extract_flag_value() {
  local flag_re="$1"
  local cmd="$2"
  local v
  v=$(echo "$cmd" | sed -nE "s/.*(${flag_re})[[:space:]]+\"([^\"]*)\".*/\2/p" | head -1)
  if [ -n "$v" ]; then echo "$v"; return; fi
  v=$(echo "$cmd" | sed -nE "s/.*(${flag_re})[[:space:]]+'([^']*)'.*/\2/p" | head -1)
  if [ -n "$v" ]; then echo "$v"; return; fi
  v=$(echo "$cmd" | sed -nE "s/.*(${flag_re})[[:space:]]+([^[:space:]]+).*/\2/p" | head -1)
  echo "$v"
}

BODY=$(extract_flag_value '--body|-b' "$COMMAND")
BODY_FILE=$(extract_flag_value '--body-file' "$COMMAND")
if [ -z "$BODY_FILE" ]; then
  # -F may also be a key=val for `gh api`; only treat it as a file ref
  # when the value has no `=`.
  F_VAL=$(echo "$COMMAND" | sed -nE "s/.*(^|[[:space:]])-F[[:space:]]+([^[:space:]]+).*/\2/p" | head -1)
  if [ -n "$F_VAL" ] && ! echo "$F_VAL" | grep -q '='; then
    BODY_FILE="$F_VAL"
  fi
fi
BODY_FILE_CONTENT=""
if [ -n "$BODY_FILE" ] && [ -f "$BODY_FILE" ]; then
  BODY_FILE_CONTENT=$(cat "$BODY_FILE" 2>/dev/null)
fi

HAYSTACK=$(printf '%s\n%s\n' "$BODY" "$BODY_FILE_CONTENT")

if [ -z "$HAYSTACK" ] || [ "$HAYSTACK" = $'\n' ]; then
  exit 0
fi

# Load config (exempt-labels, keywords).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
EXEMPT_LABELS=""
KEYWORDS=""
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/hooks/_lib-read-config.sh" ]; then
  # shellcheck disable=SC1090,SC1091
  . "$REPO_ROOT/.claude/hooks/_lib-read-config.sh"
  EXEMPT_LABELS=$(config_get '.qa.exempt_labels[]' 2>/dev/null | tr '\n' '|' | sed 's/|$//')
  KEYWORDS=$(config_get '.qa.autoclose_keywords[]' 2>/dev/null | tr '\n' '|' | sed 's/|$//')
fi
if [ -z "$EXEMPT_LABELS" ]; then
  EXEMPT_LABELS="qa-bypass"
fi
if [ -z "$KEYWORDS" ]; then
  KEYWORDS="Closes|Fixes|Resolves|Close|Fix|Resolve|Closed|Fixed|Resolved"
fi

# Extract all `<KEYWORD> #N` references from body.
# Pattern: word-boundary keyword (case-insensitive), spaces, optional `:`, `#`, digits.
REFS=$(echo "$HAYSTACK" \
  | grep -ioE "\b(${KEYWORDS})\b[[:space:]:]+#[0-9]+" 2>/dev/null \
  | grep -oE '#[0-9]+' \
  | tr -d '#' \
  | sort -u)

if [ -z "$REFS" ]; then
  # No auto-close form → allow (operator uses Refs, or no link at all).
  exit 0
fi

# Resolve target repo for label lookup. Prefer --repo, then origin, then upstream.
CMD_REPO=$(echo "$COMMAND" | sed -nE 's/.*--repo[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)
TARGET_REPO="$CMD_REPO"
if [ -z "$TARGET_REPO" ]; then
  ORIGIN_URL=$(git remote get-url origin 2>/dev/null)
  TARGET_REPO=$(echo "$ORIGIN_URL" | sed -nE 's|.*[:/]([^/:]+/[^/]+)\.git$|\1|p; s|.*[:/]([^/:]+/[^/]+)$|\1|p' | head -1)
fi
if [ -z "$TARGET_REPO" ]; then
  # Can't resolve repo → can't look up labels → allow (no false-positive block).
  exit 0
fi

BLOCKERS=""
for N in $REFS; do
  LABELS=$(gh issue view "$N" --repo "$TARGET_REPO" --json labels --jq '.labels[].name' 2>/dev/null)
  GH_RC=$?
  if [ "$GH_RC" -ne 0 ]; then
    # Issue doesn't exist (or auth failure). Let validate-pr-create.sh's
    # ticket-existence backstop handle the "doesn't exist" case.
    continue
  fi

  if [ -n "$LABELS" ] && echo "$LABELS" | grep -qE "^(${EXEMPT_LABELS})$"; then
    continue
  fi

  BLOCKERS="${BLOCKERS}${N} "
done

if [ -z "$BLOCKERS" ]; then
  exit 0
fi

cat >&2 <<MSG
BLOCKED: PR body uses an auto-close keyword (Closes / Fixes / Resolves) on
production-class issue(s) without an exempt label.

Auto-close references found: ${BLOCKERS}
Repo: ${TARGET_REPO}

ApexYard QA gate (workflows/sdlc.md § Phase 5, .claude/rules/workflow-gates.md):

  Build → Review → Merge → QA → Done

  Production-class tickets MUST route through QA after merge. The 'Closes/
  Fixes/Resolves #N' form auto-closes the issue on merge, skipping Salim
  (QA Engineer) entirely.

Two ways to unblock:

  1. Switch to 'Refs #N' (preferred):
     The PR body links the issue but does NOT auto-close it. After merge,
     the move-to-qa-on-merge workflow auto-applies the 'qa' label, which
     activates Salim per role-triggers.md. Salim verifies AC, applies
     'qa-passed', then closes.

  2. Apply an exempt label to the issue, then retry:
     For infra-class chores with no user-facing AC:
       gh issue edit ${BLOCKERS} --repo ${TARGET_REPO} --add-label chore

     Exempt labels (any one is enough): chore, docs, spike, infra, qa-bypass

     'qa-bypass' is the catch-all for one-off exceptions (legal-mandated
     hotfix, broken-fork sync, etc.). Use sparingly.

The exempt set is configurable in .claude/project-config.json:
  .qa.exempt_labels[]       — overrides the default list
  .qa.autoclose_keywords[]  — overrides the default keyword set

See AgDR for the design rationale (docs/agdr/AgDR-0031-qa-chain-mechanization.md).
MSG
exit 2
