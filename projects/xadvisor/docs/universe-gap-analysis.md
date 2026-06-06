# EGX Universe Gap Analysis — xadvisor#34

## Summary

This document describes what the PIT universe infrastructure can and cannot deliver given
the available free data sources. It is the honest basis for `ValidationFlags.survivorship_bias`
remaining `"reduced"` (not `False`) after this ticket.

---

## What Was Built

- `egx_ticker_master.csv` — seed file covering the 34 EGX-33 Shariah whitelist entries
- `egxdata/portfolio/universe_history.py` — PIT construction: `_symbols_active_at`, coverage
  report, `load_pit_universe`, `build_pit_universe_table`
- `egxdata/portfolio/universe.py` — `build_research_universe(as_of)` using the above
- `egxdata/cli.py` — `seed-universe` (scrape current EGX listing) and `universe-coverage`
- `egxdata/storage/db.py` — `Ticker` extended with `listed_date`, `delisted_date`,
  `listing_status`; `list_symbols_as_of(as_of)` added

---

## Data Source Limitations

### Free sources: stockanalysis.com + Yahoo Finance

Both only return **currently active listings**. Characteristics:

| Property | Status |
|----------|--------|
| Current active EGX stocks | Available |
| Current delisted stocks | NOT available |
| Historical listing dates | Partially — stockanalysis shows some IPO years |
| Historical delisting dates | NOT available |
| Stocks delisted before ~2022 | NOT recoverable |

### What `seed-universe` can do

Running `egx seed-universe` scrapes stockanalysis.com and merges into `egx_ticker_master.csv`.
This adds any **currently active** EGX stock not already in the seed file. It does **not** add
stocks that were active in, say, 2018 and delisted before 2022 — those are invisible to free
scraping.

### What remains unknown

- Approximately 20–40 EGX stocks believed to have traded during 2018–2022 and subsequently
  delisted, suspended, or merged are not in any free datasource we can access
- Exact listing/delisting dates for most stocks in the seed file are blank (NULL)
- NULL dates are handled conservatively (always included) to avoid silently shrinking the
  universe, but this means some incorrectly active-looking names may appear in early periods

---

## Survivorship Bias Assessment

### Current state: `survivorship_bias = "reduced"`

The PIT infrastructure removes **future** survivorship bias (new backtests will record which
stocks were in the universe at each observation date). However:

- Pre-2022 periods will still be missing delisted names we can't recover
- The seed file's NULL listed/delisted dates mean the PIT filter treats all 34 Shariah names
  as active from the beginning of time — conservative but not accurate

### Path to `survivorship_bias = False`

This would require **one of**:

1. Purchase of official EGX historical listing/delisting data (EGX Data Products)
2. Manual curation from EGX annual reports + gazette announcements (multi-week effort)
3. A third-party data provider with full Egyptian market history

None of these are available as part of this ticket's scope.

### Impact on backtest validity

| Period | Expected quality | Notes |
|--------|-----------------|-------|
| 2024–present | Clean | All current stocks covered; PIT tracked going forward |
| 2022–2023 | Good | Most active stocks available via scraping; few gaps |
| 2019–2021 | Reduced bias | Universe mostly correct; ~10–20 delisted names missing |
| Pre-2019 | High survivorship bias | Only EGX-33 Shariah names available; heavy omissions |

For IC / signal research using post-2022 data, the research universe is sufficiently complete.
For pre-2022 ablation studies or survivorship-bias sensitivity analysis, this limitation must
be disclosed in any paper or report.

---

## Coverage Flag Interpretation

`universe_coverage_report()` produces a `sparse_flag` column. When `sparse_flag=True`
(below 40% price coverage for the active universe), signal IC computed for that period
should be treated with extra caution — data gaps may explain any apparent alpha.

Typical pattern:
- Post-2021 periods: dense (most active stocks have price files)
- 2019–2021: moderate sparsity depending on how many stocks have been fetched
- Pre-2019: always sparse until a comprehensive data fetch covers older history

---

## Recommended Next Steps (out of scope for #34)

1. Run `egx seed-universe` after initial setup to expand master beyond the 34-name seed
2. Manually add known major delistings (e.g. merged banks, privatised state enterprises)
   to `egx_ticker_master.csv` with their actual delisting dates
3. Run `egx universe-coverage` periodically to monitor coverage trends
4. File a separate ticket if EGX official data becomes available — update
   `ValidationFlags.survivorship_bias` to `False` at that point

---

*Last updated: 2026-06-04 — xadvisor#34*
