# xadvisor — Architecture

| Diagram | Source | Last generated |
|---------|--------|----------------|
| [Container (C4 L2)](./container.md) | `/handover` (machine-drafted starting point) | 2026-06-03 |
| [Data Flow Diagram](./dfd.md) | `/dfd xadvisor` | 2026-06-03 |

L1 (Context) deferred — single-service CLI; the L2 container diagram already captures the external actors (researcher, yfinance, stockanalysis, IMF). Add an L1 if/when xadvisor becomes one of several services in a larger system.

Source of truth: `/threat-model xadvisor` and `/compliance-check xadvisor` snapshot the DFD into their own audit outputs at run time — editing `dfd.md` does NOT invalidate previously-written audits. Re-run the audit to refresh.
