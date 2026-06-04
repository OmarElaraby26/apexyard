---
id: AgDR-0001
timestamp: 2026-06-03T15:54:00Z
agent: claude
model: claude-opus-4-7
trigger: user-prompt
status: executed
---

# AgDR-0001 — Anti-scope: Freeze Strategy at Top-10 Equal-Weight Until Phase 1.5 Passes

> In the context of the xadvisor validation roadmap (2026-06-03), facing the canonical quant-project failure mode where strategy complexity grows faster than validation evidence, I decided to freeze the production strategy at **Top-10 equal-weight from the Shariah subset, monthly rebalance** with no further factor / weighting / regime-detection changes, to ensure all engineering capacity flows to validation work, accepting that any genuine alpha source we miss during the freeze will still be available after the freeze ends.

## Context

After a 6-round technical review chain on 2026-06-03, both the reviewer and the working agent converged on the conclusion: *"Validation harness is the product now. Strategy stays simple."*

The current xadvisor system already has:

- Composite ranking (Piotroski + Magic Formula + QVM + GARP)
- Top-10 equal-weight portfolio construction
- Walk-forward backtest infrastructure
- Live tracking ledger
- Observability layer (regime tracking + health-check)

What it does NOT have, and what blocks any honest reading of the current backtest:

- Point-in-time fundamentals (composite uses snapshot-today)
- Point-in-time Shariah membership (2026 list applied backward)
- Reduced survivorship bias only (today's EGX-33 applied backward)
- Cross-sectional statistical power (only 33 names per period)

Most quant projects die not because the math is wrong, but because the strategy keeps evolving — new factors, weighting schemes, regime detectors, ML overlays, optimizer stacks — until the strategy becomes an optimized description of the past that is impossible to trust.

The discipline of freezing the strategy while improving the validation evidence is what separates projects that produce reliable outcomes from projects that produce backtests.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Freeze Top-10 EW until Phase 1.5 passes** | Forces validation focus; prevents factor creep; preserves baseline for clean comparison; matches reviewer + worker consensus. | Loses option value if a genuinely better strategy could be found during the freeze window. (Mitigation: it remains discoverable AFTER the freeze ends.) |
| **Freeze indefinitely** | Maximum simplicity discipline. | Closes the door on any future evolution even if validation proves the signal is strong; over-restrictive. |
| **Soft preference, no hard freeze** | Maintains flexibility. | Reverts to the failure mode this AgDR is trying to prevent — strategy drifts while validation work waits. |
| **Freeze AND require an AgDR before any future change** | Strong discipline with explicit unfreeze mechanism. | Functionally equivalent to "freeze until Phase 1.5 verdict + future AgDR". (This is essentially what we are choosing.) |

## Decision

Chosen: **Freeze Top-10 EW until Phase 1.5 passes, with an explicit AgDR-required unfreeze mechanism**, because:

1. It matches the engineering plan converged in the 2026-06-03 review chain.
2. It prevents the well-documented quant-project failure mode of factor / complexity creep.
3. It is not permanent — Phase 1.5 verdict is the trigger that re-opens the question.
4. It preserves a clean baseline: when Phase 1.5 produces the bias-attribution report, the comparison is meaningful because the strategy didn't move under the report.

## Scope of the freeze

**Frozen** (no changes without a new AgDR overriding this one):

- Composite signal definition (Piotroski + Magic Formula + QVM + GARP — no additions, no removals, no reweighting)
- Portfolio size: Top-10
- Portfolio weighting: equal-weight
- Rebalance frequency: monthly
- Investable universe filter: Shariah-compliant only
- No regime detection / regime switching
- No ML / AI market prediction
- No new optimizer integration

**Not frozen** (active work):

- Data validity work (PIT fundamentals, PIT Shariah membership, historical universe) — these are the entire point of the freeze
- Phase 1.5 bias-attribution report
- Live OOS tracking continuation
- Observability metrics that report on the strategy without modifying it

## Unfreeze conditions

The freeze ends when ALL of the following are true:

1. Phase 1.5 re-baseline gate ([OmarElaraby26/xadvisor#35](https://github.com/OmarElaraby26/xadvisor/issues/35)) produces a SURVIVE classification on the 4 pre-committed axes (see AgDR-0002)
2. A follow-up AgDR is written that explicitly references this one and authorises a specific change
3. The change passes Rex review

Plan-level "go" or roadmap-level enthusiasm does not unfreeze the strategy — only an explicit AgDR does.

## Consequences

- During the freeze window, any proposal to add a factor / change weighting / try a different rebalance frequency must be deferred or written into a follow-up AgDR for the post-1.5 decision phase.
- The Phase 1.5 report compares a stable strategy against itself on different data shapes. The comparison is meaningful because the strategy didn't move.
- If Phase 1.5 verdict is COLLAPSE, the freeze is moot — the project is reassessed entirely (research-success outcome, archive or pivot).
- The bus-factor-1 risk on this project means the discipline relies on the single contributor. Recording the decision here makes it auditable and revisitable.

## Artifacts

- [`projects/xadvisor/validation-roadmap.md`](../../validation-roadmap.md) — the converged roadmap
- [Phase 1 ticket #32 — PIT fundamentals](https://github.com/OmarElaraby26/xadvisor/issues/32)
- [Phase 1 ticket #33 — PIT Shariah membership](https://github.com/OmarElaraby26/xadvisor/issues/33)
- [Phase 1 ticket #34 — Historical research universe](https://github.com/OmarElaraby26/xadvisor/issues/34)
- [Phase 1.5 ticket #35 — re-baseline gate](https://github.com/OmarElaraby26/xadvisor/issues/35)
- [Spike #31 — Shariah PIT data obtainability](https://github.com/OmarElaraby26/xadvisor/issues/31)
- Sibling AgDR-0002 — success criteria framework
