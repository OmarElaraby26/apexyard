---
id: AgDR-0002
timestamp: 2026-06-03T15:55:00Z
agent: claude
model: claude-opus-4-7
trigger: user-prompt
status: executed
---

# AgDR-0002 — Pre-Committed Evaluation Framework for the Phase 1.5 Re-Baseline Verdict

> In the context of the xadvisor validation roadmap (2026-06-03), facing the well-documented risk of post-hoc threshold rationalisation once cleaned data is in hand, I decided to **pre-commit to the EVALUATION FRAMEWORK now (axes + decision shape) and calibrate NUMERICAL THRESHOLDS only after the Phase 1.5 report exists**, to ensure the success criteria cannot be reverse-engineered to fit whatever the data turns out to show, accepting that the exact pass/fail numbers cannot be locked until we know what the clean baseline looks like.

## Context

A persistent failure mode in quantitative research:

> Pick numerical success thresholds AFTER seeing results, then declare the result a success or failure relative to those thresholds.

This is motivated reasoning. The threshold is chosen with the result already visible. Every quant project that does this convinces itself the result is meaningful regardless of what the data says.

The 2026-06-03 review chain caught an early version of this AgDR proposing concrete thresholds (≥15% alpha → keep, 5-15% → ship small, ≤5% → kill). The reviewer's pushback was sharp:

> The decision tree looks more precise than reality. A validated 8% annual alpha over a passive benchmark can be extremely valuable. The question is "5% above what, at what risk?" — those matter more than the absolute number. And we do not yet know what the clean results look like.

The corrected approach: **define the framework now, calibrate the numbers later** — and crucially, define the SHAPE of the decision (axes + outcome classes) up-front so the calibration cannot become rationalisation.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Define framework + axes now, calibrate numbers after Phase 1.5 report** | Prevents post-hoc threshold-fitting on the decision shape; preserves honest calibration of cut-points once distribution of clean results is known. | Slightly less concrete up-front; relies on discipline at calibration time. (Mitigation: framework is recorded here; future calibration must reference this AgDR.) |
| **Hardcode concrete thresholds now (e.g. ≥15% / 5-15% / ≤5%)** | Maximally explicit; no calibration step. | Numbers are arbitrary before cleaned data exists; they may be too lax or too strict; will get rationalised retroactively anyway. |
| **No formal framework — trust judgment at verdict time** | Lightweight. | Reverts to the failure mode we are trying to prevent. |
| **Multiple competing thresholds, pick at verdict** | Defers commitment. | Same as hardcoding multiple variants — still arbitrary, and inviting cherry-picking. |

## Decision

Chosen: **Framework + axes locked now; thresholds calibrated after Phase 1.5 report exists, with calibration mechanics recorded against this AgDR.**

## The framework (locked now — cannot change between now and Phase 1.5 verdict)

### Axes

The Phase 1.5 outcome is judged on FOUR axes. All four are addressed in the report. No axis is dropped or substituted retrospectively.

1. **Rank IC sign + magnitude**
   - Positive on Shariah subset?
   - Positive on full-EGX universe?
   - Stable across subperiods (no single regime carrying the result)?

2. **Top-10 vs benchmark**
   - Beats EGX-index passive benchmark?
   - Beats Shariah-passive alternative (if such an instrument exists / can be proxied)?
   - All comparisons NET of indicative transaction cost (cost model TBD as part of Phase 2 if reached)

3. **Cost robustness**
   - Survives realistic transaction + slippage assumptions for EGX liquidity?
   - Edge does not vanish entirely once cost is taken into account?

4. **Subperiod stability**
   - Holds across bull / bear / flat / devaluation / high-rate / low-rate regimes, to the extent the data sample spans them?
   - No single regime contributing >70% of the cumulative result?

### Outcome classes (locked now)

The Phase 1.5 report classifies the outcome into ONE of three shapes:

- **SURVIVE** — Signal magnitude is meaningful across ALL 4 axes. Promote Phase 2 backlog active.
- **AMBIGUOUS** — Signal is meaningful on 2-3 axes; 1-2 axes show weakness or noise. Pause; targeted follow-up to disambiguate before any Phase 2 commitment.
- **COLLAPSE** — Signal is weak on multiple axes. Research success (we now know the previously-reported edge was bias-driven). Archive system as research artifact OR pivot to passive Shariah index for capital deployment.

### Numerical thresholds (deliberately NOT locked now)

These will be calibrated AFTER the Phase 1.5 report exists, against the distribution of cleaned results, with a follow-up AgDR (AgDR-0003+) that:

1. Cites this AgDR as the framework being calibrated against
2. Names the specific numerical cut-points per axis (e.g. "rank IC >0.05 with t-stat >2 across subperiods = pass on axis 1")
3. Explains the basis for the cut-point (e.g. statistical significance, comparison to published EGX-baseline studies if available, or comparison to passive-benchmark IR)
4. Cannot be retroactively softened to fit the result — the AgDR is written BEFORE the verdict is declared

## Why deferring numbers is the right call

The reviewer's argument is load-bearing:

- A validated 5-8% alpha over benchmark, net of cost, with positive IR — is genuinely valuable in EGX context
- A reported 25-40% CAGR with PIT contamination — is genuinely worthless

We cannot judge "what alpha magnitude is meaningful" without knowing what the clean baseline returns (positive benchmarks vs negative? high-vol vs low-vol?). Locking 5% / 15% NOW pretends to a precision we cannot have.

We CAN lock the SHAPE of the decision NOW: 4 axes, 3 outcome classes, calibration-via-future-AgDR rule. That shape cannot be retroactively bent.

## Anti-rationalisation guards (locked now)

1. The Phase 1.5 report MUST classify into one of {SURVIVE, AMBIGUOUS, COLLAPSE}. No new outcome class invented post-hoc.
2. The calibration AgDR (AgDR-0003 if reached) MUST be written BEFORE the report's verdict is read in the calibration meeting. Author signs that no specific numerical results were consulted while writing the cut-points.
3. If a result is on the borderline of a class, default to the more conservative class (AMBIGUOUS over SURVIVE, COLLAPSE over AMBIGUOUS). Burden of proof is on declaring the signal real, not on declaring it absent.
4. The 4 axes cannot be selectively reported. Report shows all 4 even if some are weaker than others.

## Consequences

- Phase 1.5 verdict produces an outcome class via pre-committed rules, not via post-hoc storytelling.
- A future calibration AgDR must be written to set concrete cut-points; this preserves audit trail and forces explicit decision-making.
- If the calibration is genuinely difficult (e.g. Phase 1.5 results are deeply ambiguous), the system defaults to AMBIGUOUS, which means "do more work before committing Phase 2 capacity" — a conservative default.
- The discipline relies on the author writing the calibration AgDR honestly. Bus-factor-1 makes this an integrity test; recording the rule here makes the test auditable.

## Artifacts

- [`projects/xadvisor/validation-roadmap.md`](../../validation-roadmap.md) — the converged roadmap
- [Phase 1.5 ticket #35](https://github.com/OmarElaraby26/xadvisor/issues/35) — the gate that consumes this framework
- Sibling AgDR-0001 — anti-scope: freeze strategy at Top-10 EW
- Future AgDR-0003 (TBD) — numerical calibration AgDR, only written once Phase 1.5 report exists
