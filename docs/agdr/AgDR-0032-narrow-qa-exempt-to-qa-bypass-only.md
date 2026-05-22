# Narrow `qa.exempt_labels` to `qa-bypass` only

> In the context of QA-chain v1 (AgDR-0031) silently auto-exempting four classes of work from Salim's verification — `chore`, `docs`, `spike`, `infra` — and a concrete incident where kt-sdk issues #9 (LICENSE) and #10 (uv lock) closed via the `chore` exemption without anyone verifying the change, I decided to **shrink the default exempt set to `["qa-bypass"]` only**, leaving `qa-bypass` as the explicit, deliberate, per-ticket escape valve, to achieve "every ticket through Salim by default", accepting that adopters lose the convenience of class-of-work auto-exemption and must consciously apply `qa-bypass` per-ticket on the rare exceptions where genuinely warranted.

## Context

AgDR-0031 § Vocabulary defined the exempt set as `chore`, `docs`, `spike`, `infra`, `qa-bypass`. Rationale: "infra-class work with no user-facing AC doesn't need Salim's AC walk."

This rationale conflated TWO things:

1. **Content**: does the ticket have user-facing acceptance criteria to check?
2. **Verification value**: is there any verification pass that adds confidence?

Class-of-work auto-exemption assumed "no user-facing AC = no verification value". That's wrong. Even chores can regress (CI workflow broken on the first PR after install; coverage threshold off-by-five; license metadata in the wrong field). Salim's role is not only "walk the AC checklist" — it's also "the second pair of eyes on what just landed". Auto-exempting four common label classes meant the second pair of eyes was systematically skipped.

Concrete trigger: on 2026-05-22, CEO observed that kt-sdk #9 (Apache-2.0 license adoption) and #10 (uv lock + workspace) had auto-closed via `Closes #N` on merge without any Salim sign-off — both `chore`-labeled, both allowed through by qa-gate.yml's exempt-set check. The chain mechanism held by design but the design was wrong about what to exempt.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **A. Keep 5-label exempt set (AgDR-0031 status)** | No code change; matches "no user-facing AC" rationale | Silently bypasses verification on chores, docs, spikes, infra. The bypass scales with project activity — every chore PR (the bulk of operational work) skips QA forever |
| **B. Shrink to `["qa-bypass"]` only [CHOSEN]** | Every ticket flows through Salim; `qa-bypass` becomes explicit per-ticket choice; matches the CEO intent that the gate is universal | Adopters must run Salim on chores too — small ongoing cost per ticket; for trivial chores Salim's verification is a quick "the file landed, CI ran clean" check rather than full AC walk |
| **C. Per-class verification depth** (e.g. chores get "shallow" QA, features get "deep" QA) | Calibrates Salim effort to ticket weight | Hard to mechanize the distinction; adds rule complexity; the wrong shade of "no-op exemption" reappears as "trivially shallow verification" |
| **D. Time-bounded exemption** (chores auto-close after 7-day cooling-off if no opposition) | Provides a verification window without manual Salim pass | Adds wall-clock state to the chain; not mechanically friendly to GitHub's event model; surprising to operators |
| **E. Per-project override only** (defaults to `qa-bypass` only; adopters configure broader sets via `.claude/project-config.json`) | Gives adopters local flexibility | Operationally identical to (B) at framework level; the per-project override path already exists via shallow-merge config |

## Decision

**Option B — shrink to `["qa-bypass"]` only.**

Implementation:

1. `.claude/project-config.defaults.json` — `.qa.exempt_labels = ["qa-bypass"]`
2. Hook fallback strings updated: `block-closes-without-exempt-label.sh` + `block-issue-close-without-qa-passed.sh`
3. `golden-paths/pipelines/qa-gate.yml` — env-default updated to `qa-bypass`
4. Rule + role files updated to reflect the narrow exempt set + new vocabulary
5. Hook tests flip the chore/spike ALLOW cases to BLOCK + add new docs/infra BLOCK cases
6. AgDR-0031 § Vocabulary is hereby superseded re: the exempt-set membership; everything else in AgDR-0031 (the four-piece chain, the `qa-passed` label, the `Refs`/`Closes` semantic) remains in force.

`qa-bypass` semantic stays unchanged: it's the deliberate per-ticket escape valve. Operators apply it consciously, on the rare exceptions where verification truly isn't valuable — legal-mandated hotfixes, broken-fork sync chores, framework self-bootstrap (this ticket and PR are themselves labeled `qa-bypass` precisely because the implementing PR cannot wait for Salim to audit the policy change before allowing the policy change to merge).

## Consequences

- **Every ticket through Salim** — chores included. Salim's verification on chores is typically lighter than on features (often "file landed cleanly, CI ran green, no obvious regression") but the pass is mandatory.
- **`qa-bypass` use surfaces as conscious choice** — operators must edit a label per ticket they intend to bypass. The label's presence is auditable; widespread `qa-bypass` use shows up in metrics as a process smell rather than as invisible auto-exemption.
- **Migration to managed repos** — the policy shift propagates via `/update` on each adopter fork. kt-sdk (the only managed repo currently) gets retro-QA on its previously chore-exempt closures (#9, #10) as a sibling task. Adopters with other already-closed chore tickets must decide whether to retro-QA per repo — the chain doesn't reopen retroactively (qa-gate.yml fires on close events, not on policy changes).
- **Per-project override path remains** — adopters who genuinely need a wider exempt set can override via `.claude/project-config.json` `.qa.exempt_labels[]`. The override should be documented + time-bounded if used; the narrow default is the prescribed baseline.
- **AgDR-0031 partial supersession** — only the exempt-set membership changes. The four-piece chain (PR-create hook + close hook + move-to-qa workflow + qa-gate workflow), the `qa-passed` verified label, the `Refs` vs `Closes` semantic, and `bin/apexyard-init-labels` all stay intact.
- **Reversibility** — widening the exempt set is just a config edit. The constraint here is the policy stance, not the implementation. If a future operator decides the trade-off was wrong, the path back is one PR.

## Artifacts

- Ticket: https://github.com/OmarElaraby26/apexyard/issues/3 (labeled `qa-bypass` — self-bootstrap)
- PR: pending (this branch)
- AgDR-0031 — predecessor; partially superseded re: the exempt-set membership
- AgDR-0030 — the skill-gated ticket-create hook that makes ticket filing structured (referenced here because it's the upstream of the labeling discipline this AgDR depends on)
- Hooks: `.claude/hooks/block-closes-without-exempt-label.sh`, `.claude/hooks/block-issue-close-without-qa-passed.sh`
- Workflow: `golden-paths/pipelines/qa-gate.yml`
- Role: `roles/engineering/qa-engineer.md`
- Rules: `.claude/rules/git-conventions.md`, `.claude/rules/pr-workflow.md`, `.claude/rules/workflow-gates.md`
- Tests: `.claude/hooks/tests/test_block_closes_without_exempt.sh` (10 cases), `.claude/hooks/tests/test_block_issue_close_without_qa.sh` (21 cases)
