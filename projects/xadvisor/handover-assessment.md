# xadvisor — Handover Assessment

**Date**: 2026-06-03 (adopted) · **Completed**: 2026-06-03
**Assessor**: Omar Elaraby
**Status**: active (handover complete — see "Handover Completion" section below)

## Origin

- **Where it came from**: Personal research toolkit by the fork owner; adopted into ApexYard governance now.
- **Original owner**: Omar Elaraby (sole contributor to date).
- **Repo location**: https://github.com/OmarElaraby26/xadvisor (cloned to `workspace/xadvisor/`).
- **First commit date**: 2026-06-03 (entire git history is within the last 24 hours — repo is fresh; the work itself is older but the published history is new).
- **Last commit date**: 2026-06-03 (HEAD: `cc0a1d5 chore(scripts): decile-test runner`).
- **Repo name vs package name**: GitHub repo is `xadvisor` but the Python package + CLI entry-point are named `egxdata` (`egx` command). Disambiguate everywhere — the project name in this assessment uses the repo slug.

## Current State

### Tech stack

- **Language**: Python 3.12+ (`requires-python = ">=3.12"`).
- **Runtime**: CPython only (no async event loop in the hot path; httpx used in sync mode).
- **CLI framework**: `typer 0.26` (entry-point `egx = "egxdata.cli:app"`).
- **Data libs**: `pandas 2.2`, `pyarrow 15`, `selectolax 0.3` (HTML scraping), `lxml`, `html5lib`.
- **HTTP**: `httpx 0.27` + `hishel` (cache) + `tenacity` (retry).
- **Storage**: `duckdb 1`, `sqlalchemy 2` over local SQLite, parquet for time-series.
- **Optimization / ML**: `pyportfolioopt 1.5.5`, `cvxpy 1.5`, `scikit-learn 1.3`.
- **Validation**: `pydantic 2`.
- **Test framework**: `pytest` (not pinned in `pyproject.toml`; installed ad-hoc during this handover via `uv pip install pytest`).
- **Package manager**: `uv` (lockfile `uv.lock` present at root).
- **CI**: NONE — no `.github/workflows/`, no other pipeline config detected.

### Build status

- `uv sync`: ok (resolves + installs all deps cleanly into `.venv/`).
- `pytest`: 1 failed / 122 passed — see Quality Risks below.
- Lint (`ruff check`): not attempted in this handover; ruff is configured in `pyproject.toml` so the baseline exists.
- Type check: NOT ATTEMPTED — no mypy/pyright config exists.

### Test coverage

- Unknown — no `coverage` / `--cov` config in `pyproject.toml`, no coverage step anywhere.
- README claims "118 tests passing" — reality is 123 (122 pass + 1 fail). Doc is mildly stale.

### Repo activity

- Commits in last 90 days: 9 (entire history).
- Open issues: 0.
- Open PRs: 0.
- Top contributors: Omar Elaraby (sole contributor → **bus factor = 1**).

## Harnessability assessment

**Overall verdict**: `low`

> ⚠ Harnessability: LOW
>
> Rex's architecture handbooks will fire advisory-only on this codebase. The blocking gate (`ENFORCEMENT: blocking`) will generate false positives. Recommended: adopt as advisory-only, plan a follow-up to add the missing scaffolding (typescript strict, lint baseline, etc.)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Type safety | `none` | No `mypy.ini`, no `[tool.mypy]` block, no `pyrightconfig.json`. `pyproject.toml` configures `ruff` only. Source code uses `from __future__ import annotations` + PEP-604 hints but nothing enforces them. |
| Module boundaries | `partial` | `egxdata/{portfolio, sources, storage}/` sub-packages give clear thematic layering (signal vs IO vs persistence), but no clean-architecture `domain/application/infrastructure` split. |
| Framework opinionation | `weak` | `typer` CLI + scientific-Python libs (pandas, sklearn, cvxpy, pyportfolioopt). No HTTP / persistence / DI framework supplying conventions or test scaffolding. |
| Test coverage signal | `absent` | No `[tool.coverage]`, no `--cov` flag in any config, no coverage step in any pipeline (and no pipeline). |
| Lint baseline | `present` | `[tool.ruff]` configured with `E, F, I, W, B, UP, SIM` selects and `py312` target. |

Score: 1 of 5 dimensions in the strong/present bucket; combined with `type_safety = none` AND `framework = weak`, the override kicks in → verdict `low`. See AgDR-0042 for the scoring rationale and v1 thresholds.

## Quality Risks

### Security

- **No secrets in source** — scanned `egxdata/**/*.py` for `api_key|password|secret|token`, no hits. No `.env*` files in repo. All data sources (yfinance, stockanalysis.com, IMF) are public, no API keys required.
- **No auth/crypto surface** — toolkit is read-only against public sources and writes to local SQLite + parquet on disk; no user authentication, no encryption, no HTTPS server.
- **Web-scraping fragility** — `egxdata/sources/stockanalysis.py` parses HTML via `selectolax`. Upstream HTML changes silently break the universe refresh; no contract test against a saved fixture.

### Dependencies

- **`pyportfolioopt 1.5.5`** is several minor versions behind (latest 1.6.x installed by `uv sync` is `pyportfolioopt==1.6.0`, so `>=1.5.5` floats forward — OK). Re-pin if a 1.6 incompatibility surfaces.
- **`scikit-learn 1.3`** floor is from 2023; installed version pulled in `1.9.0`. Wide drift — verify nothing in the codebase relies on deprecated 1.3-era APIs.
- **`cvxpy 1.5`** + **`scs`** — both compile native code; will need re-resolution on Python upgrades.
- No `pip-audit` / `safety` run in this handover; run `/audit-deps` to triage CVEs.

### Technical debt

- **No type checking** — modules use PEP-604 hints in places but nothing enforces consistency or catches regressions.
- **1 failing test** — `tests/golden/test_twr.py::test_synthetic_real_world_walk_forward_twr` fails with `sqlite3.OperationalError: unable to open database file`. Looks like the test expects a `data/` directory the test runner doesn't create. Test-infra issue, not a domain bug.
- **README claims "118 tests passing"** — actual count is 123 (122 pass + 1 fail). Doc drift.
- **README references a private path** (`/home/elaraby/.claude/plans/cozy-soaring-pearl.md`) — strip before any external sharing.
- **Single contributor** — bus factor 1; no review history exists yet.
- **Notebooks unsynced** — `notebooks/` directory present but not part of the test or lint surface.

### Operational

- **No CI** — every push lands on `main` with no automated check; no protection against the failing test recurring or regressing.
- **No deploy automation** — research toolkit, runs locally; expected, but worth naming.
- **No observability outside the in-app `health-check` command** — the README's "observability layer" is project-domain observability (regime tracking), not runtime observability.
- **Single branch (`main`)** — no protected-branch policy; PR workflow has never been used here yet.

### Domain / research caveats (not technical bugs — documented honest limits)

The README explicitly surfaces these. Listed here so the assessment reflects them, not because the code is broken:

- `survivorship_bias: "reduced"` (today's EGX-33 list applied backward to 2024-Q1).
- `pit_fundamentals: True` (composite uses today's fundamentals snapshot).
- 26-month sample, 32 names, one regime (post-2024-Q1 recovery). Statistical power is thin.
- README's reviewer-converged framing: *"You have built a correct and disciplined observability + portfolio system, but you are still in the phase of collecting evidence, not evaluating truth."*

## Integration Plan

### Roles that apply

- `tech-lead` — every project gets one.
- `backend-engineer` — Python module work, scoring/portfolio/storage logic.
- `data-engineer` — ETL from web sources to parquet + SQLite (`sources/`, `storage/`).
- `data-analyst` — composite scoring, backtest interpretation, A/B-shaped method comparison (`signal-test`, `health-check`).

Not activated (no signal): `frontend-engineer` (no UI), `platform-engineer` (no CI yet — flips on the moment CI is added), `sre` (no production deployment), `security-auditor` (no auth/crypto/secrets diff).

### Workflows that kick in

- [ ] PR workflow (`.claude/rules/pr-workflow.md`) — every change goes through a PR (currently the repo has never used PRs).
- [ ] AgDR for technical decisions — start tracking method-selection / library-choice calls.
- [ ] Code Reviewer agent on every PR (Rex, advisory-only given low harnessability).
- [ ] `/audit-deps` on adoption and monthly thereafter.

### Hooks to enable

- [ ] `block-git-add-all`
- [ ] `block-main-push`
- [ ] `validate-branch-name` (set `ticket_prefix` for this project's tracker — GitHub Issues `#N`).
- [ ] `validate-pr-create`
- [ ] `pre-push-gate` (will need a project-specific command: `uv run pytest && uv run ruff check`).
- [ ] `check-secrets`

### CI templates to copy in

- [ ] `golden-paths/pipelines/ci.yml` (will need Python-stack adjustments — the default is TypeScript-leaning).
- [ ] `golden-paths/pipelines/pr-title-check.yml`.
- (No `golden-paths/pipelines/security.yml` analogue for Python — substitute `pip-audit` or `safety` step.)

### Registry entry

Appended to `apexyard.projects.yaml` (step 7):

```yaml
- name: xadvisor
  repo: OmarElaraby26/xadvisor
  workspace: workspace/xadvisor
  docs: projects/xadvisor
  status: handover
  roles:
    - tech-lead
    - backend-engineer
    - data-engineer
    - data-analyst
```

## Next Steps

1. ~~Fix the 1 failing test in `tests/golden/test_twr.py` (sqlite path / `data/` dir not created by test fixture) before merging new PRs — baseline must be green.~~ → Filed as [#1](https://github.com/OmarElaraby26/xadvisor/issues/1)
2. ~~Set up test coverage reporting (`pytest-cov` + `[tool.coverage]` in `pyproject.toml` + a CI step) before the first feature, so future PRs can be evaluated against a baseline.~~ → Filed as [#2](https://github.com/OmarElaraby26/xadvisor/issues/2)
3. ~~Add a CI pipeline — copy `golden-paths/pipelines/ci.yml`, adapt to `uv sync && uv run pytest && uv run ruff check`, enable on push + PR.~~ → Filed as [#3](https://github.com/OmarElaraby26/xadvisor/issues/3)
4. ~~`/audit-deps xadvisor` — triage any CVEs in `pyportfolioopt` / `cvxpy` / `scikit-learn` / `httpx` chain before the first feature merge.~~ → Filed as [#4](https://github.com/OmarElaraby26/xadvisor/issues/4)
5. ~~Add `mypy` (or `pyright`) config + a CI typecheck step — raises the harnessability score from `low` toward `moderate` and lets Rex's blocking gates fire usefully on architecture handbooks.~~ → Filed as [#5](https://github.com/OmarElaraby26/xadvisor/issues/5)
6. ~~Scrub the private path reference from the README (`/home/elaraby/.claude/plans/cozy-soaring-pearl.md`) before any external visibility.~~ → Filed as [#6](https://github.com/OmarElaraby26/xadvisor/issues/6)
7. Stakeholder sync with the previous owner (Omar himself) to cover context the static read couldn't surface — research roadmap, which signals to keep / drop, which constraints are load-bearing vs aspirational.
8. `/code-review` the most-recent PR on this repo as Rex to calibrate review standards (NB: zero PRs exist yet — first PR will set the baseline).

## Post-Handover Checklist

- [ ] Review this assessment with the previous owner (Omar — same person, but the discipline of re-reading from a "previous-owner" hat helps).
- [ ] Fix the failing `test_twr.py` test before any new feature PR.
- [ ] Set up `pytest-cov` + coverage baseline in the first 2 weeks.
- [ ] Add `xadvisor` to the weekly `/stakeholder-update` rollup.
- [ ] Onboard the 4 listed roles into the team's review rotation (all currently the same person; pre-document where the handoffs would split if/when a second contributor joins).
- [ ] Run `/audit-deps xadvisor` monthly for the next 3 months.
- [ ] Establish a single source of truth for "what tests exist" — update README's "118 tests passing" line whenever the count moves.
- [ ] Configure `mypy` to ratchet type coverage upward over time.

## Open Questions — Resolved 2026-06-03

- **Repo vs package name** — RESOLVED: keep both. The repo is `xadvisor` (product surface); the Python package + CLI entry-point is `egxdata` / `egx` (implementation detail). Confirmed against `workspace/xadvisor/pyproject.toml` (`[project] name = "egxdata"`). Documentation discipline: external mentions use `xadvisor`; in-code module references use `egxdata`. Renaming either side would be churn without payoff — they describe different things (the product vs the toolkit it ships).
- **What does the `notebooks/` directory contain?** — RESOLVED: research scratch / pipeline walkthrough. Contains 5 sequential notebooks (`01_egypt_macro.ipynb` → `02_egx_universe.ipynb` → `03_screener.ipynb` → `04_score_rank.ipynb` → `05_portfolio_optimization.ipynb`) that mirror the runtime data pipeline. Treatment: keep in repo as research artefact / onboarding aid; not load-bearing context; no test surface needed. Document purpose in README on next pass.
- **Does the README's "production recommendation" reflect live trading intent?** — RESOLVED via [AgDR-0001](docs/agdr/AgDR-0001-anti-scope-freeze-strategy.md): live trading is **premature** until the Phase 1.5 re-baseline gate ([#35](https://github.com/OmarElaraby26/xadvisor/issues/35)) produces a SURVIVE classification. The 47% CAGR figure in the current README is bias-contaminated and not a basis for capital deployment. Until validation completes, the system is treated as a research artefact, not a production trading signal. The READ ME line "Place actual trades via your broker" is **deprecated** and will be revisited at the Phase 1.5 verdict meeting per the success-criteria framework ([AgDR-0002](docs/agdr/AgDR-0002-success-criteria-framework.md)).
- **`onboarding.yaml` placeholder warning** — DEFERRED to framework-level work. Affects all projects in the ops fork (not xadvisor specifically). Run `/setup` on the ops fork before the next cross-project rollup. Tracked separately from xadvisor handover.

## Handover Completion — 2026-06-03

Handover marked **complete** on 2026-06-03. Registry status flipped from `handover` to `active`. Project now under normal SDLC governance.

### Artefacts produced during handover

- This assessment document (`handover-assessment.md`)
- Architecture L2 container stub (`architecture/container.md`)
- Validation roadmap (`validation-roadmap.md`) — 6-round technical review chain converged on Phase 1 + Phase 1.5 work plan
- AgDR-0001 (anti-scope: freeze Top-10 EW until 1.5 passes)
- AgDR-0002 (pre-committed success criteria framework)
- 6 initial Next-Steps tickets ([#1-#6](https://github.com/OmarElaraby26/xadvisor/issues?q=is%3Aissue+%231..%236))
- 5 validation tickets ([#31-#35](https://github.com/OmarElaraby26/xadvisor/issues?q=is%3Aissue+%2331..%2335)) — Phase 1 + Phase 1.5

### What "active" means in the registry

- Default SDLC gates apply (PR workflow, code reviewer agent, design review where UI is touched, QA verification, AgDR for technical decisions)
- The 4 listed roles (tech-lead, backend-engineer, data-engineer, data-analyst) auto-activate per `.claude/rules/role-triggers.md`
- `/inbox`, `/status`, `/tasks`, `/stakeholder-update` include xadvisor in their cross-project rollups
- Migration ticket gate fires on any DB / schema-related edit (none currently planned)

### Next actions for the active phase

1. Start spike [#31](https://github.com/OmarElaraby26/xadvisor/issues/31) (3-day budget) — Shariah PIT data obtainability
2. Address infra tickets in parallel: #1 (failing test), #2 (coverage), #3 (CI), #5 (mypy), #6 (README scrub)
3. Spike disposition gates #33; Phase 1 tickets (#32, #33, #34) all gate Phase 1.5 (#35)
