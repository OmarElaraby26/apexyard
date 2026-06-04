# xadvisor — Validation Roadmap

**Date**: 2026-06-03
**Author**: Omar Elaraby
**Status**: locked (convergence reached over 6-round technical review chain on 2026-06-03)

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

## Phase 2+ — Backlog (do NOT promote pre-1.5)

Per reviewer + worker convergence, do not pre-commit Phase 2 engineering. Building elaborate validation machinery on a signal that doesn't survive PIT cleanup is the canonical quant project failure mode. Backlog items, gated on Phase 1.5 verdict:

| # | Title | Promote when |
|---|-------|--------------|
| E | Walk-forward purged CV + embargo validation harness | 1.5 verdict ≥ ambiguous-survive |
| F | Transaction cost + EGX liquidity model | 1.5 verdict ≥ ambiguous-survive |
| G | Live OOS tracking continuation (multi-year, parallel) | Already running — continue regardless |
| H | Multiple-testing correction (Bonferroni / FDR / White / SPA) | Promote IF Phase 4 factor expansion ever happens |
| I | Signal half-life / decay measurement | 1.5 verdict ≥ survive |
| J | Factor attribution (which composite leg drives the edge) | 1.5 verdict ≥ survive |

Filed as a single backlog memo ticket, not as active tickets. Promotion = a 1.5-verdict review meeting + an explicit decision.

## Phase 3 — Live OOS (parallel, ongoing)

Live tracking continues regardless of 1.5 outcome. It is the only ground truth in the long run. No amount of offline validation replaces years of real-money observation.

## Phase 4 — Reassess factor expansion (gated)

Only after Phase 1.5 AND Phase 3 produce converging "yes there is real edge" evidence. Otherwise skipped indefinitely. This is the phase that breaks the anti-scope freeze if reached.

## Roadmap structure summary

```
Spike (Shariah data obtainability)
  └─► [PASS] ──► Task B (PIT Shariah membership) ──┐
Task A (PIT fundamentals) ───────────────────────────┼──► Task D (Phase 1.5 gate)
Task C (Historical universe) ────────────────────────┘         │
                                                                ▼
                                                          DECISION
                                                          /        \
                                              [SURVIVE]              [COLLAPSE]
                                                  │                       │
                                       Promote Phase 2 backlog    Archive / pivot
                                       (Tasks E, F, I, J)         (research success)
                                                  │
                                          [Phase 3 continues in parallel always]
                                                  │
                                       [Phase 4 gated on 1.5 + 3 convergence]
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

## Filing status (2026-06-03)

All Phase 1 + Phase 1.5 tickets filed. AgDRs committed. Anti-scope locked. Pre-committed evaluation framework locked.

| Artifact | Location | Status |
|----------|----------|--------|
| Spike — Shariah PIT data obtainability | [OmarElaraby26/xadvisor#31](https://github.com/OmarElaraby26/xadvisor/issues/31) | Filed |
| Task A — PIT fundamentals | [OmarElaraby26/xadvisor#32](https://github.com/OmarElaraby26/xadvisor/issues/32) | Filed |
| Task B — PIT Shariah membership | [OmarElaraby26/xadvisor#33](https://github.com/OmarElaraby26/xadvisor/issues/33) | Filed (blocked by #31) |
| Task C — Historical research universe | [OmarElaraby26/xadvisor#34](https://github.com/OmarElaraby26/xadvisor/issues/34) | Filed |
| Task D — Phase 1.5 re-baseline gate | [OmarElaraby26/xadvisor#35](https://github.com/OmarElaraby26/xadvisor/issues/35) | Filed (blocked by #32, #33, #34) |
| AgDR-0001 — Anti-scope freeze | [docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md](docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md) | Committed |
| AgDR-0002 — Success criteria framework | [docs/agdr/AgDR-0002-success-criteria-framework.md](docs/agdr/AgDR-0002-success-criteria-framework.md) | Committed |

Phase 2+ items remain in the backlog section of this document — not filed as active tickets. Promotion = a Phase 1.5 verdict review meeting + explicit `/decide` AgDR-0004+ authorising the next-phase work.

## Next action

Start the spike (#31). The spike disposition gates everything else in Phase 1. Begin with a quick survey of public + commercial Shariah-screening data sources, budget 3 days, write the disposition memo, then promote or pivot.

The next high-value artifact after the spike is the Phase 1.5 bias-attribution report — not another planning round.
