# Mechanize the QA chain end-to-end

> In the context of an SDLC where the QA gate (workflows/sdlc.md § Phase 5) was prose-only at three load-bearing transitions, facing a real incident where three production PRs auto-closed their tickets on merge and bypassed Salim (QA Engineer) entirely, I decided to ship a four-piece defense-in-depth mechanism (two PreToolUse hooks + two GitHub Actions workflows + an exempt-label set + a verified-label requirement), to achieve mechanical enforcement at every transition with one consistent vocabulary, accepting that adopters need to seed labels via `bin/apexyard-init-labels` on each managed repo and that infra-class chores still need explicit exempt-labeling rather than implicit bypass.

## Context

The QA gate is the load-bearing quality boundary between merge and ticket Done. It is described in three places:

- `workflows/sdlc.md` § Phase 5 — "tickets cannot move to Done without QA verification"
- `.claude/rules/workflow-gates.md` § "QA State is Mandatory" — same statement in prose
- `roles/engineering/qa-engineer.md` § "QA Sign-off Format" — sign-off template that lives on its own

None of these were mechanically enforced. Three conventions hold the chain together:

1. **PR body uses `Refs #N`** (not `Closes #N`) so the issue survives merge
2. **Operator applies `qa` label** after merge to activate Salim
3. **Salim signs off** before anyone closes the ticket

All three conventions are exploitable by writing the wrong magic words.

**Incident (2026-05-21):** three PRs on a managed project (kt-sdk #2/#4/#7) used `Closes #N`. GitHub auto-closed issues #1/#3/#6 on merge. Salim was never activated. The bypass was implicit and silent — neither the operator nor any review surfaced it. The CEO caught it by asking "did QA review happen?".

Tickets happened to be infra-class chores (CI workflow, coverage config) with no user-facing AC, so no harm done. But the chain didn't distinguish "exempt chore" from "feature that accidentally bypassed QA" — both produced the same outcome. The chain has no mechanical floor that says "this class of ticket NEEDS QA".

## Options Considered

### A. Strict prose-only with quarterly audits

Keep the rule as documentation. Run a quarterly audit script (`gh issue list --closed --no-label qa-passed`) to spot bypasses.

**Pros:** zero implementation cost; no false positives.
**Cons:** misses the bypass at the moment it happens; correction is retroactive (issue already closed, ticket-vocabulary trust broken). Doesn't actually prevent the failure mode.

### B. Single PreToolUse hook at close-time only

Block `gh issue close` if `qa-passed` not present.

**Pros:** simple; one file.
**Cons:** misses the upstream cause — `Closes #N` in PR bodies auto-closes via GitHub's auto-closer, which doesn't go through `gh issue close`. The webhook fires on a merge event and closes the issue server-side. Local hook never sees the close command at all. Half-fix.

### C. Single server-side workflow (qa-gate only)

GitHub Actions workflow on `issues.closed` that reopens any issue without `qa-passed`.

**Pros:** catches all close paths (CLI, web UI, auto-close-on-merge); can't be bypassed locally.
**Cons:** reactive — the issue gets closed first, then reopened. Operator sees a Slack/email notification for the close, then another for the reopen; confusing UX. Also doesn't catch the PR-create source of bypass (operator writes `Closes #N` and gets feedback only after merge).

### D. Defense in depth — hook (PR-create) + hook (close) + workflow (route-to-QA) + workflow (close safety net) [CHOSEN]

Four pieces:

1. **Client hook 1** — `block-closes-without-exempt-label.sh` rejects `gh pr create` with `Closes #N` on a non-exempt issue. Fast feedback at the source of bypass.
2. **Client hook 2** — `block-issue-close-without-qa-passed.sh` rejects `gh issue close` / `gh issue edit --state closed` / `gh api .../issues/N` with `state=closed` if no `qa-passed` and no exempt label. Catches local close attempts on the wrong path.
3. **Server workflow 1** — `move-to-qa-on-merge.yml` on `pull_request.closed (merged=true)` parses `Refs #N`, applies the `qa` label. Activates Salim automatically; closes the "operator forgot to label" gap.
4. **Server workflow 2** — `qa-gate.yml` on `issues.closed` reopens the issue if no `qa-passed` and no exempt label. Safety net for web UI / mobile / direct-API closes that bypass the client hooks.

**Pros:** every transition gated; client-side gives instant feedback; server-side is the can't-bypass floor; defense in depth is the only shape that holds against the real failure modes (web UI close, auto-close on merge, raw `gh api`).
**Cons:** four files to keep in sync; adopters need to seed labels first.

**Why CHOSEN over (B) or (C) alone:** the failure modes are diverse (six different close paths across CLI, web UI, GitHub auto-closer, API). A single gate can't catch all of them. The four-piece set covers the matrix.

### E. Force everyone to use `/qa-close` skill

Wrap the close in a structured skill that applies `qa-passed` + closes atomically. Forbid raw `gh issue close`.

**Pros:** auditable via the skill marker (same pattern as `/approve-merge`); structured.
**Cons:** doesn't catch the auto-close-on-merge case (PR body says `Closes`; GitHub auto-closes without going through any skill or local command); doesn't catch web UI closes; adds yet another skill in the operator's flow.

Folded into (D) instead: the closing protocol in the Salim role file documents the `gh issue edit --add-label qa-passed && gh issue close` two-step. A skill could come later if the manual form proves error-prone.

## Decision

Chosen: **Option D — defense in depth**.

Four mechanical pieces, one consistent label set:

| Layer | Mechanism | Catches |
|-------|-----------|---------|
| Client, PR creation | `.claude/hooks/block-closes-without-exempt-label.sh` | `gh pr create` with `Closes/Fixes/Resolves #N` on non-exempt issue |
| Client, issue close | `.claude/hooks/block-issue-close-without-qa-passed.sh` | `gh issue close`, `gh issue edit --state closed`, `gh api .../issues/N` with `state=closed` |
| Server, post-merge | `golden-paths/pipelines/move-to-qa-on-merge.yml` | Auto-applies `qa` label on PR merge → activates Salim |
| Server, close gate | `golden-paths/pipelines/qa-gate.yml` | Reopens issues closed without `qa-passed` and without exempt label |

Vocabulary:

- `qa` — applied automatically post-merge; activates Salim
- `qa-passed` — applied by Salim after verification; required to close (or have an exempt label)
- `chore`, `docs`, `spike`, `infra`, `qa-bypass` — exempt labels (allow auto-close + allow close without `qa-passed`)

> **Superseded by [AgDR-0032](AgDR-0032-narrow-qa-exempt-to-qa-bypass-only.md)**: the 5-label class-of-work exempt set caused silent QA bypass on chores. The exempt set was narrowed to `["qa-bypass"]` only — `qa-bypass` is now the sole class-level exempt, applied per-ticket as a deliberate escape valve. Everything else in this AgDR (the four-piece chain, the `qa-passed` semantic, the `Refs`/`Closes` rule) remains in force.

Config knobs in `.claude/project-config.defaults.json` under `.qa.*`:

- `exempt_labels[]` — defaults to `[chore, docs, spike, infra, qa-bypass]`
- `autoclose_keywords[]` — defaults to `[Closes, Fixes, Resolves, Close, Fix, Resolve, Closed, Fixed, Resolved]`
- `verified_label` — defaults to `qa-passed`
- `qa_label` — defaults to `qa`

Adopters override via `.claude/project-config.json` shallow merge.

Label seed via `bin/apexyard-init-labels <owner/repo>` (idempotent).

## Consequences

- Every production-class ticket routes through Salim by mechanical enforcement, not convention.
- Infra-class chores still close fast via exempt label — but the label is EXPLICIT, not implicit. The author must declare exemption up front, not retroactively via auto-close magic.
- Adopters need to run `bin/apexyard-init-labels` on each managed repo once. /handover should offer this as a follow-up in a later iteration (out of scope for v1).
- `roles/engineering/qa-engineer.md` documents the two-step closing protocol; Salim applies the label by hand. Auto-detecting Salim's sign-off comment to apply the label is v2.
- Adopters with the legacy convention (close via web UI, no labels) will see their next close auto-reopened. The reopen comment explains the gate.
- The four-piece set is the minimum that holds against all six close paths. Removing any one reopens a hole.
- Per-project exempt-label customization (a managed-project might want `experimental` or `internal-tool` exempt) is v2 — v1 ships a fixed set with global config override.

## Artifacts

- Issue: https://github.com/OmarElaraby26/apexyard/issues/1
- PR: pending (this branch)
- Hooks: `.claude/hooks/block-closes-without-exempt-label.sh`, `.claude/hooks/block-issue-close-without-qa-passed.sh`
- Workflows: `golden-paths/pipelines/move-to-qa-on-merge.yml`, `golden-paths/pipelines/qa-gate.yml`
- Label-init script: `bin/apexyard-init-labels`
- Rule updates: `.claude/rules/git-conventions.md`, `.claude/rules/pr-workflow.md`, `.claude/rules/workflow-gates.md`
- Role update: `roles/engineering/qa-engineer.md`
- Hook tests: `.claude/hooks/tests/test_block_closes_without_exempt.sh`, `.claude/hooks/tests/test_block_issue_close_without_qa.sh`
- Config defaults: `.claude/project-config.defaults.json` § `.qa.*`
