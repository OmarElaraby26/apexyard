#!/bin/bash
# PreToolUse hook on issue-close commands. Blocks the close if the issue
# does NOT carry `qa-passed` AND does NOT carry one of the exempt labels.
#
# Three close shapes covered:
#   1. gh issue close <N>
#   2. gh issue edit <N> --state closed                (uncommon but supported)
#   3. gh api -X PATCH repos/<owner>/<repo>/issues/<N> -f state=closed
#
# Same exempt-label set as block-closes-without-exempt-label.sh.
#
# If the SAME command also applies `qa-passed` via --add-label, the close
# is allowed (atomic "verify + close" path used by Salim).
#
# Exit codes:
#   0 = allowed
#   2 = blocked

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Detect close intent.
IS_CLOSE=0
if echo "$COMMAND" | grep -qE '\bgh\s+issue\s+close\b'; then
  IS_CLOSE=1
elif echo "$COMMAND" | grep -qE '\bgh\s+issue\s+edit\b.*--state[[:space:]=]+closed'; then
  IS_CLOSE=1
elif echo "$COMMAND" | grep -qE '\bgh\s+api\b.*repos/[^/[:space:]]+/[^/[:space:]]+/issues/[0-9]+\b' \
     && echo "$COMMAND" | grep -qE '(-f|--field|--raw-field)[[:space:]]+state=closed'; then
  IS_CLOSE=1
fi

if [ "$IS_CLOSE" = "0" ]; then
  exit 0
fi

# Extract issue number(s). Multiple numbers possible on `gh issue close 1 2 3`.
NUMS=""
if echo "$COMMAND" | grep -qE '\bgh\s+issue\s+close\b'; then
  # All positional args after `close` and before any -- or --flag.
  NUMS=$(echo "$COMMAND" \
    | sed -E 's/.*\bgh\s+issue\s+close\b//' \
    | grep -oE '^[[:space:]]+([0-9]+([[:space:]]+[0-9]+)*)' \
    | grep -oE '[0-9]+' \
    | tr '\n' ' ')
fi
if [ -z "$NUMS" ] && echo "$COMMAND" | grep -qE '\bgh\s+issue\s+edit\b'; then
  # All positional args after `edit` and before any -- or --flag.
  # Matches the multi-number shape `gh issue edit N1 N2 N3 --state closed`.
  NUMS=$(echo "$COMMAND" \
    | sed -E 's/.*\bgh\s+issue\s+edit\b//' \
    | grep -oE '^[[:space:]]+([0-9]+([[:space:]]+[0-9]+)*)' \
    | grep -oE '[0-9]+' \
    | tr '\n' ' ')
fi
if [ -z "$NUMS" ]; then
  NUMS=$(echo "$COMMAND" | grep -oE 'repos/[^/[:space:]]+/[^/[:space:]]+/issues/[0-9]+' | grep -oE '[0-9]+$')
fi

if [ -z "$NUMS" ]; then
  # Couldn't extract number → let gh fail with its own error.
  exit 0
fi

# Resolve target repo.
CMD_REPO=$(echo "$COMMAND" | sed -nE 's/.*--repo[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)
if [ -z "$CMD_REPO" ]; then
  CMD_REPO=$(echo "$COMMAND" | grep -oE 'repos/[^/[:space:]]+/[^/[:space:]]+/issues/' | sed -nE 's|repos/([^/]+/[^/]+)/issues/|\1|p' | head -1)
fi
if [ -z "$CMD_REPO" ]; then
  ORIGIN_URL=$(git remote get-url origin 2>/dev/null)
  CMD_REPO=$(echo "$ORIGIN_URL" | sed -nE 's|.*[:/]([^/:]+/[^/]+)\.git$|\1|p; s|.*[:/]([^/:]+/[^/]+)$|\1|p' | head -1)
fi
if [ -z "$CMD_REPO" ]; then
  exit 0
fi

# Detect atomic "verify + close" — same command applies qa-passed.
# Use an explicit non-suffix terminator after `qa-passed` so labels like
# `qa-passed-but-not-really` or `qa-passed-prod` do NOT match. The terminator
# is end-of-string, whitespace, comma (label list separator), or quote.
SAME_COMMAND_PASS=0
if echo "$COMMAND" | grep -qE -- '--add-label[[:space:]=]+([^[:space:]]+,)?qa-passed([[:space:],"'"'"']|$)'; then
  SAME_COMMAND_PASS=1
fi
if echo "$COMMAND" | grep -qE '(-f|--field|--raw-field)[[:space:]]+labels\[\]=qa-passed([[:space:]"'"'"']|$)'; then
  SAME_COMMAND_PASS=1
fi

# Load config.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
EXEMPT_LABELS=""
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/hooks/_lib-read-config.sh" ]; then
  # shellcheck disable=SC1090,SC1091
  . "$REPO_ROOT/.claude/hooks/_lib-read-config.sh"
  EXEMPT_LABELS=$(config_get '.qa.exempt_labels[]' 2>/dev/null | tr '\n' '|' | sed 's/|$//')
fi
if [ -z "$EXEMPT_LABELS" ]; then
  EXEMPT_LABELS="chore|docs|spike|infra|qa-bypass"
fi

BLOCKERS=""
for N in $NUMS; do
  LABELS=$(gh issue view "$N" --repo "$CMD_REPO" --json labels --jq '.labels[].name' 2>/dev/null)
  GH_RC=$?
  if [ "$GH_RC" -ne 0 ]; then
    # Issue not found / auth failure → defer to gh's own error.
    continue
  fi

  if [ "$SAME_COMMAND_PASS" = "1" ]; then
    continue
  fi
  if [ -n "$LABELS" ] && echo "$LABELS" | grep -qE "^(${EXEMPT_LABELS})$"; then
    continue
  fi
  if [ -n "$LABELS" ] && echo "$LABELS" | grep -q '^qa-passed$'; then
    continue
  fi

  BLOCKERS="${BLOCKERS}${N} "
done

if [ -z "$BLOCKERS" ]; then
  exit 0
fi

cat >&2 <<MSG
BLOCKED: Cannot close issue(s) without QA verification.

Blocking issues: ${BLOCKERS}
Repo: ${CMD_REPO}

ApexYard QA gate (workflows/sdlc.md § Phase 5):

  in_progress → in_review → qa → qa-passed → close

A ticket reaches the close state ONLY when one of these is true:
  - it carries the 'qa-passed' label (Salim verified every AC), OR
  - it carries an exempt label (chore / docs / spike / infra / qa-bypass —
    infra-class work with no user-facing AC)

To unblock:

  1. Have Salim (QA Engineer) verify the ticket end-to-end. On pass:
       gh issue edit ${BLOCKERS} --repo ${CMD_REPO} --add-label qa-passed
       gh issue close ${BLOCKERS} --repo ${CMD_REPO}

     Or, atomically (recognised by this hook):
       gh issue close ${BLOCKERS} --repo ${CMD_REPO}
       # then immediately:
       gh issue edit  ${BLOCKERS} --repo ${CMD_REPO} --add-label qa-passed
       # — the close fails first time; rerun after the label lands

  2. If the ticket truly has no user-facing AC, apply an exempt label:
       gh issue edit ${BLOCKERS} --repo ${CMD_REPO} --add-label chore

The exempt set is configurable in .claude/project-config.json:
  .qa.exempt_labels[]

See AgDR for the design rationale (docs/agdr/AgDR-0031-qa-chain-mechanization.md).
MSG
exit 2
