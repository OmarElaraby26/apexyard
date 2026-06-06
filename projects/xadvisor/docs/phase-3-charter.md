# xadvisor — Phase 3 Monitoring + Evidence Accumulation Charter

**Authorized**: 2026-06-06 (Phase 2 SURVIVE verdict, issue #106)
**Author**: Omar Elaraby
**Review cadence**: Quarterly reviews; annual charter review

---

## Project state (at Phase 3 entry)

- **Signal existence**: supported by Phase 1.5 / 1.75 / 2 evidence
- **Investability**: NOT YET established — Phase 2 SURVIVE means "remains worthy of continued observation," NOT "operationally validated"
- **AgDR-0001 anti-scope freeze**: REMAINS IN FORCE — no new factors, no optimizer revisit, no strategy changes
- **Phase 3 framing**: monitoring + evidence accumulation — NOT operational deployment, NOT capital decisions

---

## Cadence

**Quarterly** reviews. Monthly is too noisy for fundamental signals; quarterly aligns with earnings releases, fundamentals refresh, and IC measurement windows.

First review: **2026-09-06** (~3 months from Phase 2 close on 2026-06-06)

Annual charter review: each year evaluate whether the charter still serves its purpose. Charter scope stays at 1 page — if it grows, scope has drifted.

---

## Metrics tracked (4 only)

| Metric | Definition |
|--------|------------|
| Live IC | Rank correlation of composite scores with realized forward returns |
| Live alpha | Top-10 EW net return minus chosen benchmark return |
| Turnover | Rebalance turnover per quarter |
| Max drawdown | Running peak-to-trough on live portfolio |

---

## Quarterly review process

Each quarter, produce a 5-line table:

| Metric | Previous | Current | Comment |
|--------|----------|---------|---------|
| Live IC | x | y | Stable / improved / weakened |
| Live alpha | x | y | Relative to benchmark |
| Turnover | x | y | Within expected range |
| Drawdown | x | y | Acceptable / notable |

Then decide **one** of:

- **CONTINUE** monitoring (default)
- **SCHEDULE** formal evidence review (if observation window threshold reached — see Phase 4 trigger below)
- **ABORT** Phase 3 (if catastrophic — e.g. live IC negative for multiple consecutive quarters)

Record the decision + table in `workspace/xadvisor/docs/phase-3/YYYY-QN-review.md`.

---

## Phase 4 review trigger

**Time-based + evidence-based. NO numerical performance threshold.**

- Minimum observation window: **8 quarters** of live data (adjustable at first annual charter review)
- Trigger: observation window reached AND formal evidence review explicitly scheduled
- NOT: "if live IR > X" or "if alpha > Y%" or "if IC > Z"

Numerical thresholds chosen after seeing live results = post-hoc fitting risk — the same failure mode AgDR-0002 / AgDR-0003 anti-rationalisation guards prevent.

---

## Anti-pattern — canonical monitoring-phase failure mode

> "If quarterly reviews start generating multiple new tickets each quarter, Phase 3 has quietly turned back into Phase 2."

Quarterly reviews **EXPLICITLY MAY NOT** trigger:

- New factor proposals
- Composite changes / reweighting / leg removal
- Optimizer revisits
- Regime models
- ML overlays
- Dynamic weighting
- Parameter tweaks disguised as "investigation"
- Phase 4 work disguised as "exploration"

If a quarterly review surfaces something interesting, it stays as a research-evidence note in that quarter's review log — NOT a new ticket. Phase 4 review triggers only via the time + evidence mechanism above, not via ad-hoc reaction.

---

## What Phase 3 is NOT

- Not operational deployment
- Not capital allocation
- Not a reason to unfreeze AgDR-0001 anti-scope
- Not a research sprint in disguise

---

## References

- Phase 2 verdict: [xadvisor#106](https://github.com/OmarElaraby26/xadvisor/issues/106)
- Anti-scope freeze: [AgDR-0001](agdr/AgDR-0001-anti-scope-freeze-strategy.md) — REMAINS IN FORCE
- Signal existence ≠ investability: [AgDR-0003](agdr/AgDR-0003-phase-1-5-retrospective-calibration.md) Decision 2 — LOAD-BEARING
