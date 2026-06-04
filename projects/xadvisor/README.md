# xadvisor

EGX (Egyptian Exchange) Shariah-compliant equity research toolkit: composite scoring, Top-N equal-weight portfolio engine, walk-forward backtest, implementation-shortfall decomposition, live-tracking ledger, regime-tracking observability.

- **Repo**: https://github.com/OmarElaraby26/xadvisor
- **Workspace clone**: `workspace/xadvisor/` (gitignored)
- **Stack**: Python 3.12+ CLI (`typer`), pandas/pyarrow/duckdb/sqlalchemy storage, pyportfolioopt+cvxpy+scikit-learn optimization, httpx scraping (yfinance, stockanalysis.com, IMF).
- **Package + CLI entry-point**: `egxdata` / `egx` (the repo is `xadvisor`, the package is `egxdata` — see Open Questions in the handover assessment).
- **Owners**: Omar Elaraby (sole contributor).
- **Status**: active (handover completed 2026-06-03).

## Docs in this folder

- [`handover-assessment.md`](handover-assessment.md) — adoption-time risk + integration assessment (handover complete 2026-06-03).
- [`validation-roadmap.md`](validation-roadmap.md) — Phase 1 + Phase 1.5 plan locked after 6-round technical review chain on 2026-06-03.
- [`architecture/container.md`](architecture/container.md) — C4 L2 container diagram (machine-drafted starting point; refine).
- [`docs/agdr/`](docs/agdr/) — Agent Decision Records (AgDR-0001 anti-scope, AgDR-0002 success criteria framework).
- [`audits/`](audits/) — security / dependency / threat-model audit outputs.
