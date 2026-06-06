# xadvisor — Validation Roadmap

**Date**: 2026-06-06
**Author**: Omar Elaraby
**Status**: locked (convergence reached over 6-round technical review chain on 2026-06-03; Phase 2 SURVIVE verdict 2026-06-06)

## Project state (as of 2026-06-04)

Phase 1 + Phase 1.5 are **complete**. Verdict: **AMBIGUOUS** per the pre-committed framework in [AgDR-0002](docs/agdr/AgDR-0002-success-criteria-framework.md), calibrated retrospectively in [AgDR-0003](docs/agdr/AgDR-0003-phase-1-5-retrospective-calibration.md).

The headline finding from Phase 1.5:

> **Fundamental lookahead was material** — IC dropped from 0.112 → 0.047 in the 2020-2025 window when cleaned. In the 2022-2025 window with PIT fundamentals, the signal recovers to IC = 0.144 (t = 3.79, n = 14). Real signal survives cleanup, materially weaker than the contaminated baseline.

The project has crossed a threshold:

> **From "signal discovery" to "economic validation."** The current question is no longer *"does any signal exist at all?"* — it is *"is the surviving signal economically meaningful after costs and relative to passive alternatives?"*

### Signal existence ≠ investability (LOCKED, AgDR-0003 Decision 2)

The Phase 1.5 result supports:
- Evidence that a ranking signal may exist (IC = 0.144, t = 3.79)

The Phase 1.5 result does NOT support:
- Evidence of investability after costs
- Evidence of persistent alpha vs a tradeable passive alternative
- Evidence of robustness across regimes

These are different claims requiring different evidence. Phase 1.75 (below) exists to test the second set of claims. Phase 2 stays gated until Phase 1.75 lands a favourable verdict.

## Premise

> Validation harness is the product now. Strategy stays simple.

The current xadvisor system has a working ranking + portfolio + backtest + live-tracking + observability stack. The bottleneck is no longer engineering. The bottleneck is:

> Is the measured edge real?

That is a validation problem. All work below serves answering that question honestly before any further alpha-hunting.

## Anti-scope (frozen until Phase 1.5 verdict in)

- No new factors added to composite (no earnings revisions, no RSI, no buybacks, no ROIC, no FCF yield)
- No portfolio complexity (Top-10 equal-weight remains; no dynamic-N, no weighting schemes, no optimizer revisit)
- No regime detection / regime switching
- No ML / AI market prediction
- No additional health-check metrics (diminishing returns)

Captured as [AgDR-0001 — Anti-scope: freeze strategy at Top-10 EW until Phase 1.5 passes](docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md).

## Pre-committed evaluation framework

Defined now (before cleaned data exists) so post-hoc rationalization is impossible. Numerical thresholds calibrated only after Phase 1.5 results are visible.

Axes for judging Phase 1.5 outcome:

1. **Rank IC sign + magnitude** — positive on Shariah subset? Positive on full-EGX universe? Stable across subperiods?
2. **Top-10 vs benchmark** — beats EGX index? Beats Shariah-passive alternative? Net of transaction cost?
3. **Cost robustness** — survives realistic transaction + slippage assumptions for EGX liquidity?
4. **Subperiod stability** — holds across bull / bear / devaluation / flat / high-rate / low-rate regimes (to the extent data spans them)?

Report format: one section per axis, each with chart + number + qualitative verdict. No single "alive/dead" judgment — let evidence speak.

Captured as [AgDR-0002 — Pre-committed evaluation framework for the Phase 1.5 re-baseline verdict](docs/agdr/AgDR-0002-success-criteria-framework.md).

## Phase 1 — Data cleanup (P0)

The three contamination sources flagged in the README + handover assessment:

- `pit_fundamentals = True` (composite uses snapshot-today fundamentals)
- `lookahead_in_composite_views = True`
- `survivorship_bias = reduced` (today's EGX-33 list applied backward)

Plus one omission caught during review: **Shariah membership itself is not point-in-time**. The 2026 Shariah list cannot be applied backward to 2024 — that's another form of universe lookahead.

### Tickets (filed 2026-06-03)

| # | Title | GH issue | Blocks | Blocked by |
|---|-------|----------|--------|------------|
| Spike | Verify historical EGX Shariah PIT data obtainability (3-day budget) | [#31](https://github.com/OmarElaraby26/xadvisor/issues/31) | #33 | — |
| A | PIT fundamentals — eliminate lookahead in composite views | [#32](https://github.com/OmarElaraby26/xadvisor/issues/32) | #35 | — |
| B | PIT Shariah membership — historical compliance list | [#33](https://github.com/OmarElaraby26/xadvisor/issues/33) | #35 | #31 (spike disposition) |
| C | Historical research universe construction — delisted + historical EGX constituents (Shariah-only portfolio retained) | [#34](https://github.com/OmarElaraby26/xadvisor/issues/34) | #35 | — |

**Task C scope clarification (important):** the deliverable is NOT "list today's 200 EGX stocks". The deliverable is PIT-indexed historical universe membership including delisted / inactive / merged names per period. Naive read of "full EGX research universe" can ship as breadth without solving survivorship — explicit scope guard in the ticket body.

### Spike disposition rule (Task A's first gate)

If historical Shariah membership data is practically unobtainable, the entire validation chain breaks. Three outcomes:

- **Available** → promote to Task B, proceed as planned
- **Partial** → memo on coverage gaps, adapt Task B scope (e.g., use proxy reconstruction from debt-ratio + sector filters at PIT)
- **Unobtainable** → reopen roadmap planning; this is the one assumption that warrants going back to discussion

## Phase 1.5 — Re-baseline gate (P0)

The decision point. Cheaper to run than Phase 2 and tells us whether Phase 2 is justified at all.

### Ticket

| # | Title | GH issue | Blocked by |
|---|-------|----------|------------|
| D | Phase 1.5 re-baseline gate — bias-attribution report | [#35](https://github.com/OmarElaraby26/xadvisor/issues/35) | #32, #33, #34 |

### Required output — side-by-side bias-attribution table

The most valuable output of Phase 1.5 is NOT the new number. It is understanding **how much each bias mattered**.

| Metric | Contaminated (current) | Cleaned (new) | Delta | Bias-source attribution |
|--------|------------------------|---------------|-------|-------------------------|
| Rank IC (Shariah subset) | 0.XX | 0.XX | -XX% | PIT fundamentals: -X%, Survivorship: -Y%, PIT Shariah membership: -Z% |
| Rank IC (full EGX universe) | n/a | 0.XX | n/a | — |
| Top-10 vs EGX-index spread | XX pp | XX pp | -XX% | (same attribution) |
| Top-10 vs Shariah-passive | XX pp | XX pp | -XX% | (same attribution) |
| Sharpe ratio | X.XX | X.XX | -XX% | (same attribution) |
| Turnover (annualized) | XX% | XX% | ±XX% | (same attribution) |
| Max drawdown | -XX% | -XX% | ±XX% | (same attribution) |

If feasible: ablation runs (fix one bias at a time) to attribute the delta directly. If infeasible: side-by-side without attribution is still mandatory.

### Honest framing for the report

- Full-EGX universe = **better evidence, not definitive evidence**. Report data coverage per period (how many names with sufficient data, % missing, sparse-coverage flags). Prevents future round of "we have 200 stocks, statistical power solved" when half have <40% coverage.
- Walk-forward / live OOS still TBD post-1.5; report does NOT claim final truth.

### Decision rule at 1.5 verdict

| Outcome shape | Action |
|---------------|--------|
| Signal survives with meaningful magnitude across all 4 axes | Promote Phase 2 backlog → active |
| Signal survives ambiguously (1-2 axes weak) | Pause; targeted follow-up to disambiguate before Phase 2 |
| Signal collapses on multiple axes | Research success — document outcome, archive system as research artifact, or pivot to passive Shariah index |

## Phase 1.75 — Economic Validation (NEW, gates Phase 2)

Phase 1.5 produced an AMBIGUOUS verdict. Per AgDR-0002 outcome rules, AMBIGUOUS → "Pause; targeted follow-up to disambiguate before any Phase 2 commitment." The targeted follow-up is now formally named **Phase 1.75 — Economic Validation**.

Phase 1.75 is NOT Phase 2. It answers a different question:

| Phase | Question |
|---|---|
| Phase 1 + 1.5 | Does any signal exist after honest data cleanup? |
| **Phase 1.75 (here)** | **Is the surviving signal economically meaningful after costs and vs passive alternatives?** |
| Phase 2 (gated) | Does the validated signal warrant a full walk-forward + cost + factor-expansion harness? |

### Tickets (filed 2026-06-04)

| # | Title | GH issue | Priority | Blocked by |
|---|-------|----------|----------|------------|
| A | Model EGX transaction costs | [#72](https://github.com/OmarElaraby26/xadvisor/issues/72) | CLOSED | — |
| B | Establish benchmark framework | [#73](https://github.com/OmarElaraby26/xadvisor/issues/73) | CLOSED | — |
| C | Compute net alpha vs benchmark after costs | [#74](https://github.com/OmarElaraby26/xadvisor/issues/74) | CLOSED | — |
| D | Filing-date sensitivity for PIT fundamentals IC | [#75](https://github.com/OmarElaraby26/xadvisor/issues/75) | CLOSED | — |
| E | Pre-2022 Shariah membership investigation (spike) | [#76](https://github.com/OmarElaraby26/xadvisor/issues/76) | CLOSED | — |
| F | Lightweight within-2022 sub-regime analysis | [#77](https://github.com/OmarElaraby26/xadvisor/issues/77) | CLOSED | — |

### Phase 1.75 → Phase 2 gate criteria (locked in AgDR-0003 Decision 3)

Phase 2 promotion happens IF AND ONLY IF all of these are true after Phase 1.75 lands:

1. Cost-aware net alpha (#74) is positive vs the chosen benchmark
2. Filing-date sensitivity (#75) shows the cleaned IC is robust (not fragile to timing assumptions)
3. **New calibration AgDR-0004 written BEFORE reading the Phase 1.75 net results** (process correction from AgDR-0003 order violation — same mistake must NOT repeat)
4. Explicit promotion decision in a review meeting referencing AgDR-0001 anti-scope freeze for unfreeze authorization

If those criteria are not met, Phase 2 stays in backlog ([#70](https://github.com/OmarElaraby26/xadvisor/issues/70)).

### What Phase 1.75 will NOT do

- Will NOT promote Phase 2 backlog automatically — gate decision is explicit
- Will NOT unfreeze AgDR-0001 anti-scope (no new factors, no optimizer, no regime switching, no ML)
- Will NOT extend the clean window pre-2022 unless spike #76 produces AVAILABLE/PARTIAL data
- Will NOT change strategy complexity (Top-10 EW frozen until Phase 2 unlock)

## Phase 2 — Verdict: SURVIVE (closed 2026-06-06)

Phase 2 evaluation landed across five closed tickets (#92–#96). Overall verdict: **SURVIVE** — the system remains worthy of continued observation. SURVIVE does NOT mean operationally validated. Signal existence ≠ investability (AgDR-0003 Decision 2, load-bearing). Phase 3 authorized.

Verdict issue: [xadvisor#106](https://github.com/OmarElaraby26/xadvisor/issues/106) — CLOSED.

## Phase 3 — Monitoring + evidence accumulation (ACTIVE)

**Phase 3 is NOT operational deployment.** It is a structured evidence-accumulation phase governed by the charter at `docs/phase-3-charter.md`.

- **Cadence**: quarterly reviews
- **Metrics**: live IC, live alpha vs benchmark, turnover, max drawdown
- **Phase 4 trigger**: time-based + evidence-based only — 8 quarters minimum observation window, no numerical performance threshold
- **AgDR-0001 anti-scope freeze**: REMAINS IN FORCE throughout Phase 3
- **First review**: 2026-09-06

Canonical failure mode guard: if quarterly reviews start generating new tickets each quarter, Phase 3 has silently reverted to Phase 2. Charter explicitly forbids ad-hoc tickets from quarterly reviews.

Charter: [docs/phase-3-charter.md](docs/phase-3-charter.md) (committed 2026-06-06)

## Phase 4 — Factor expansion (FROZEN)

Only unlocks when: minimum Phase 3 observation window reached AND formal evidence review scheduled via the Phase 4 trigger mechanism in the charter. This is the phase that breaks the AgDR-0001 anti-scope freeze if reached. NOT before.

## Roadmap structure summary (updated 2026-06-06)

```
COMPLETE — Phase 1:
  Spike #31 (Shariah PIT) ──► PASS ──► Task #33 (PIT Shariah membership) ──┐
  Task #32 (PIT fundamentals) ──────────────────────────────────────────────┼──► Phase 1.5 gate (#35)
  Task #34 (Historical research universe) ──────────────────────────────────┘         │
                                                                                       ▼
                                                                              VERDICT: AMBIGUOUS
                                                                              (1 PASS / 2 WEAK / 1 NOT-COMPUTED)
                                                                                       │
                                                              ┌────────────────────────┴────────────────────────┐
                                                              ▼                                                  ▼
                                                  [WAS SURVIVE]                                       [WAS COLLAPSE]
                                                       │                                                  │
                                                       (not the verdict)                                  (not the verdict)
                                                                                                          │
                                                          ┌─── ACTUAL PATH: AMBIGUOUS ───┐
                                                          ▼                              ▼
                                                  Phase 1.75 (NEW — economic validation, this section above)
                                                          │
                                                          ▼ (after Phase 1.75 results land)
                                                  Phase 2 GATE — all 4 criteria passed
                                                  (cost-net-positive + robust + AgDR-0004 + explicit decision)
                                                          │
                                                          ▼
                                              PHASE 2 VERDICT: SURVIVE (#106, closed 2026-06-06)
                                              "Remains worthy of continued observation"
                                              Signal existence ≠ investability (still load-bearing)
                                                          │
                                                          ▼
                                              Phase 3 — monitoring + evidence accumulation (ACTIVE)
                                              Quarterly cadence · 4 metrics · 8-quarter window
                                              Charter: docs/phase-3-charter.md
                                              First review: 2026-09-06
                                              AgDR-0001 anti-scope freeze: REMAINS IN FORCE
                                                          │
                                                          ▼ (only via time+evidence trigger, no numerical threshold)
                                              Phase 4 — factor expansion (FROZEN)
                                              Breaks AgDR-0001 freeze if/when triggered
```

## What was decided during the review chain (artifact trail)

The 6-round chain (2026-06-03) extracted these load-bearing decisions:

1. Round 1 — reviewer suggested separation of research vs investable universe. Adopted.
2. Round 2 — worker flagged PIT Shariah membership as missed-bias-source; reviewer agreed. Adopted.
3. Round 3 — reviewer pushed back on "edge will disappear" framing as too strong. Adopted softer "magnitude unknown, distribution wide".
4. Round 4 — reviewer caught hardcoded 5/15% thresholds as premature; redesigned to "framework now, numbers post-data".
5. Round 5 — reviewer inserted Phase 1.5 re-baseline gate. Highest-value single addition of the chain.
6. Round 6 — reviewer moved full-EGX universe earlier (into Phase 1, not after 1.5). Adopted — makes 1.5 statistically meaningful.
7. Round 7 — reviewer added bias-attribution side-by-side and flagged Shariah PIT data risk. Both adopted; risk became the spike.
8. Round 8 — both sides converged on engineering plan. Reviewer's closing: *"Stop discussing roadmap changes. Execute Phase 1."*

## What this roadmap does NOT do

- Does not claim the investment thesis is proven (it is not)
- Does not pre-commit Phase 2 engineering
- Does not set numerical success thresholds
- Does not promise the signal will survive cleanup
- Does not add complexity to the production strategy
- Does not replace live OOS tracking

## Filing status (updated 2026-06-06)

Phase 1 + 1.5 + 1.75 + 2 complete and **closed**. Phase 3 ACTIVE. AgDR-0001 freeze in force.

| Artifact | Location | Status |
|----------|----------|--------|
| Spike — Shariah PIT data obtainability | [xadvisor#31](https://github.com/OmarElaraby26/xadvisor/issues/31) | CLOSED |
| Task — PIT fundamentals | [xadvisor#32](https://github.com/OmarElaraby26/xadvisor/issues/32) | CLOSED |
| Task — PIT Shariah membership | [xadvisor#33](https://github.com/OmarElaraby26/xadvisor/issues/33) | CLOSED |
| Task — Historical research universe | [xadvisor#34](https://github.com/OmarElaraby26/xadvisor/issues/34) | CLOSED |
| Phase 1.5 re-baseline gate | [xadvisor#35](https://github.com/OmarElaraby26/xadvisor/issues/35) | CLOSED — verdict **AMBIGUOUS** |
| Phase 1.5 report | [workspace/xadvisor/docs/phase-1-5-rebaseline-report.md](../../workspace/xadvisor/docs/phase-1-5-rebaseline-report.md) | Committed in xadvisor repo |
| Phase 1.75 — Cost model | [xadvisor#72](https://github.com/OmarElaraby26/xadvisor/issues/72) | CLOSED |
| Phase 1.75 — Benchmark framework | [xadvisor#73](https://github.com/OmarElaraby26/xadvisor/issues/73) | CLOSED |
| Phase 1.75 — Net alpha vs benchmark after costs | [xadvisor#74](https://github.com/OmarElaraby26/xadvisor/issues/74) | CLOSED |
| Phase 1.75 — Filing-date sensitivity | [xadvisor#75](https://github.com/OmarElaraby26/xadvisor/issues/75) | CLOSED |
| Phase 1.75 — Pre-2022 Shariah spike | [xadvisor#76](https://github.com/OmarElaraby26/xadvisor/issues/76) | CLOSED |
| Phase 1.75 — Within-2022 sub-regime | [xadvisor#77](https://github.com/OmarElaraby26/xadvisor/issues/77) | CLOSED |
| Phase 2 verdict gate | [xadvisor#106](https://github.com/OmarElaraby26/xadvisor/issues/106) | CLOSED — verdict **SURVIVE** |
| Phase 2 backlog memo | [xadvisor#70](https://github.com/OmarElaraby26/xadvisor/issues/70) | CLOSED — superseded by Phase 3 charter |
| **Phase 3 charter** | [docs/phase-3-charter.md](docs/phase-3-charter.md) | Committed 2026-06-06 |
| **Phase 3 charter ticket** | [xadvisor#108](https://github.com/OmarElaraby26/xadvisor/issues/108) | In QA |
| AgDR-0001 — Anti-scope freeze | [docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md](docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md) | **IN FORCE** |
| AgDR-0002 — Success criteria framework | [docs/agdr/AgDR-0002-success-criteria-framework.md](docs/agdr/AgDR-0002-success-criteria-framework.md) | In force |
| AgDR-0003 — Phase 1.5 retrospective calibration | [docs/agdr/AgDR-0003-phase-1-5-retrospective-calibration.md](docs/agdr/AgDR-0003-phase-1-5-retrospective-calibration.md) | Committed |
| AgDR-0004 — Phase 1.75 calibration | TBD | Written before Phase 1.75 net-alpha results read |

## Next action (updated 2026-06-06)

Phase 3 is active. First quarterly review: **2026-09-06**.

Immediate: track live IC, live alpha vs benchmark, turnover, max drawdown. Do NOT create new tickets from monitoring observations — research notes go in the quarterly review log only.

AgDR-0001 anti-scope freeze remains in force. Phase 4 trigger is time-based only (8 quarters minimum), not performance-based.
