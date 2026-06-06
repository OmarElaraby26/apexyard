# xadvisor — Data Flow Diagram

> **Source of truth.** This file is the canonical DFD for xadvisor. `/threat-model` and `/compliance-check` consume it instead of regenerating their own. Re-run `/dfd xadvisor` after any architecture change that adds / removes a data store, external integration, or trust boundary.

**Generated**: 2026-06-03 by `/dfd` (apexyard)
**Format**: Mermaid flowchart (renders inline on GitHub) — also available as Threat Dragon JSON via `/dfd xadvisor --format=dragon`

## Diagram

```mermaid
flowchart LR
    %% External actors (outside the local trust boundary)
    researcher([Researcher / Investor<br/>local shell])
    yfin([Yahoo Finance<br/>HTTPS, public, no auth])
    sa([stockanalysis.com<br/>HTTPS, public HTML, no auth])
    imf([openbb-imf<br/>Egypt macro via openbb API])
    broker([Broker<br/>out-of-band; fills logged manually])

    subgraph LOCAL [Local machine — single trust zone]
        direction TB
        cli[egx CLI<br/>typer entry-point]
        portfolio[Portfolio engine<br/>scoring · backtest · optimize · attribution]
        sources[Data sources adapter<br/>httpx + tenacity + pd.read_html (lxml)]

        sqlite[(SQLite<br/>tickers · refresh log · live ledger)]
        parquet[(Parquet files<br/>OHLCV · fundamentals · macro)]
    end

    %% --- Cross-boundary flows (labelled with payload) ---
    researcher -.->|"shell args: refresh-*, score, backtest,<br/>live-add-fill {symbol,price,qty}"| cli
    researcher -.->|"reads CLI stdout/stderr"| cli
    broker -.->|"out-of-band: trade confirmations<br/>(human transcribes into live-add-fill)"| researcher

    sources -.->|"HTTPS GET /history, /quote<br/>no auth"| yfin
    sources -.->|"HTTPS GET HTML pages<br/>universe + 50d OHLCV"| sa
    sources -.->|"HTTPS GET macro series<br/>JSON"| imf

    %% --- In-process flows (within local trust zone) ---
    cli --> portfolio
    cli --> sources
    cli --> sqlite

    sources --> sqlite
    sources --> parquet
    portfolio --> sqlite
    portfolio --> parquet
```

## Trust boundaries

| Boundary | Crosses | Auth | Data classifications crossing |
|----------|---------|------|-------------------------------|
| **Local machine ↔ Public internet** | `sources → {yfin, sa, openbb-imf}` | NONE — public read-only endpoints | Public (market quotes, fundamentals, macro). No request body carries identifying or PII data. |
| **Researcher ↔ CLI** | `researcher → cli` (shell args + stdout) | OS user (local shell session) | PII: live-ledger writes (`live-add-deposit`, `live-add-fill`) carry the investor's personal trade detail. Stays inside the local trust zone. |
| **Broker ↔ Researcher** (out-of-band) | `broker → researcher` (paper confirms / app notifications), then `researcher → cli` | Broker's own auth (out of scope for this codebase) | PII: trade confirmations. The codebase never touches the broker API directly — fills are manually transcribed. |

Inside the **Local machine** zone, CLI / portfolio / sources / all stores share the same OS user's filesystem credentials. No internal sub-boundary modelled (no privilege separation, no daemon, no multi-tenant).

## Data classifications

| Element | Classification | Pathway | Evidence |
|---------|----------------|---------|----------|
| `ticker.symbol`, `ticker.name`, `ticker.sector` | **Public** | schema (SQLAlchemy) | `egxdata/storage/db.py` (universe table) |
| OHLCV per-ticker parquet (open/high/low/close/volume + date) | **Public** | schema (parquet columns) | `egxdata/storage/parquet.py` + `egxdata/sources/{yfin,stockanalysis}.py` |
| Fundamentals (earnings / shares / financials) | **Public** | schema (parquet columns) | `egxdata/sources/stockanalysis.py` |
| Macro series (FX, inflation, rates) | **Public** | schema (parquet columns) | `egxdata/sources/imf_egypt.py` |
| `live_deposit.amount`, `live_deposit.date` | **PII — investor financial** | inferred from semantics (personal capital flows) | `egxdata/portfolio/live.py` |
| `live_fill.symbol`, `live_fill.qty`, `live_fill.price`, `live_fill.date` | **PII — investor financial** | inferred from semantics (personal trade records) | `egxdata/portfolio/live.py` |
| `live_status.*` (current portfolio composition, cash, returns) | **PII — investor financial** | inferred from semantics | `egxdata/portfolio/live.py` |
| Custom JSON HTTP cache contents | **Public** (derived from public sources) | inferred from upstream classification | on-disk cache dir (`egxdata/http.py`), gitignored |
| API keys / tokens / passwords | **N/A — none exist** | scan: `grep -rEi 'api[_-]?key\|password\|secret\|token' egxdata` returns zero hits | confirmed during `/handover` security scan |

**Explicit registry**: no `docs/data-classification.{md,yaml}` exists for this project. All classifications above are heuristic / semantic-inferred and may be tightened by adding an explicit registry.

## Discovery provenance

| Element | Detected via |
|---------|--------------|
| `egx CLI` process | `pyproject.toml` `[project.scripts] egx = "egxdata.cli:app"` + `egxdata/cli.py` typer app |
| `Portfolio engine` process | `egxdata/portfolio/` sub-package (12 modules: backtest, returns, covariance, expected_returns, metrics, attribution, etc.) |
| `Data sources adapter` process | `egxdata/sources/{yfin,stockanalysis,imf_egypt}.py` |
| Yahoo Finance actor | `egxdata/sources/yfin.py` |
| stockanalysis.com actor | `egxdata/sources/stockanalysis.py` + `pd.read_html` (lxml backend) HTML parsing |
| openbb-imf actor | `egxdata/sources/imf_egypt.py` + `openbb-imf` library |
| SQLite store | `egxdata/storage/db.py` (`sqlalchemy 2`) — detected by `discover.sh` as `rdbms_sqlalchemy` |
| Parquet store | `egxdata/storage/parquet.py` + `pyproject.toml` `pyarrow>=15` |
| Custom JSON HTTP cache | `egxdata/http.py` — custom JSON cache class wrapping `httpx`; no `hishel` dep |
| Researcher actor | typer CLI entry-point implies human local-shell invocation; the README's "live-tracking" section confirms the human-in-the-loop ledger workflow |
| Broker actor (out-of-band) | README § "The only meaningful next step" steps 1–3: *"Place actual trades via your broker / Log fills via egx live-add-fill / Log deposits via egx live-add-deposit"* — broker is **not** in code; flows are human-transcribed |
| Zero secrets | grep `'api[_-]?key\|password\|secret\|token'` in `egxdata/**/*.py` returns no hits; no `.env*` files in repo |
| Zero auth surface | No HTTP server, no `flask`/`fastapi`/`django` imports, no `@auth0`/`@clerk`/JWT/OIDC imports |

## Notes for downstream consumers

- **`/threat-model`** will find a narrow attack surface: no HTTP server → no Spoofing on inbound auth; no PII transmitted across the Public-internet boundary → low Info-Disclosure risk on outbound traffic; the most interesting surface is **HTML-scraping fragility** (`stockanalysis.com`) and **untrusted-data → in-process parse** (pd.read_html using lxml / html5lib backend on attacker-modifiable upstream HTML).
- **`/compliance-check`** will find no cross-border transfers initiated by this codebase (all outbound is to public, unauthenticated data sources; no DPA needed for read-only public-data scraping). The PII surface is purely local-only (live ledger) — no GDPR processor-controller relationship to model.
- **No internal sub-boundaries inside the Local zone** is a deliberate choice for v1. If a future version daemonises the data refresh under a separate OS user or splits the live ledger into a separate process, re-run `/dfd xadvisor` to add the new boundary.

---

Generated by /dfd on 2026-06-03
