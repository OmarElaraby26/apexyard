# xadvisor-ocr — Handover Assessment

**Date**: 2026-06-13
**Assessor**: Omar Elaraby
**Status**: handover

## Origin

- **Where it came from**: First-party project — authored by the same owner
- **Original owner**: OmarElaraby26
- **Repo location**: https://github.com/OmarElaraby26/xadvisor-ocr
- **First commit date**: 2026-06-09
- **Last commit date**: 2026-06-13 (active, same day as handover)

## Current State

### Tech stack

- Language: Python 3.12
- Runtime: Python (pure library — no HTTP surface)
- Framework: None (library; no web/DI/persistence framework)
- Database: None
- Test framework: pytest + pytest-cov
- CI: GitHub Actions — two-tier (fast: ~10s, slow: ~10min with live Tesseract)
- System dependency: Tesseract OCR (tesseract-ocr + ara + eng language packs)
- Production deps: opencv-python-headless, numpy, pytesseract

### Build status

- `pip install`: **blocked** — no `pyproject.toml` or `setup.py` exists; README claims `pip install -e .` but it would fail
- `pytest (fast tier)`: likely ok — CI ran recently; coverage gate 25%
- `pytest (slow tier)`: requires Tesseract system dep; coverage gate 75%; 81% reported in README
- `lint`: not configured — no lint step exists anywhere

### Test coverage

- Fast tier: ≥25% (CI gate), 56% reported in README
- Full (both tiers): ≥75% (CI gate), 81% reported in README

### Repo activity

- Commits in last 90 days: all commits (repo is 4 days old as of assessment)
- Open issues: 0
- Open PRs: 0
- Top contributors: Omar Elaraby (sole author)

## Harnessability assessment

**Overall verdict**: `low`

> ⚠ Harnessability: LOW
>
> Rex's architecture handbooks will fire advisory-only on this codebase. The blocking gate (`ENFORCEMENT: blocking`) will generate false positives. Recommended: adopt as advisory-only, plan a follow-up to add the missing scaffolding (typescript strict, lint baseline, etc.)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Type safety | `partial` | Type hints present throughout (frozen dataclasses, `str \| None`, `Literal[...]`) but no mypy.ini, pyrightconfig.json, or mypy/pyright CI step found |
| Module boundaries | `partial` | `extractor/` package with `parsers/` sub-package, but main orchestrator `local_extractor.py` lives at repo root; scratch scripts (`visualize_extraction.py`, `order_extractor.py`, `analyze_status_colors.py`) also at root |
| Framework opinionation | `weak` | Pure Python library; no HTTP, no web framework, no ORM or DI container — appropriate for the project shape |
| Test coverage signal | `present` | `.github/workflows/test.yml` sets `--cov-fail-under=25` (fast) and `--cov-fail-under=75` (full); README reports 81% coverage |
| Lint baseline | `absent` | No .flake8, .pylintrc, ruff.toml, .pre-commit-config.yaml found; no lint step in CI |

See AgDR-0042 for the scoring rationale and v1 thresholds.

## Quality Risks

### Security

- No secrets or API keys visible in the codebase (library uses only local Tesseract — no external API calls in the packaged code)
- Benchmark scripts reference Gemini (historical — early commits; not present in current `extractor/` package)
- No `.env` or `.env.example` found

### Dependencies

- **Critical: no `pyproject.toml` or `setup.py`** — README documents `pip install -e .` but the package is not installable as described; this is a blocking gap before any consumer can onboard
- Production deps (opencv-python-headless, numpy, pytesseract) are **unpinned** — only installed ad-hoc in CI via `pip install …`; no version constraints committed
- `requirements-dev.txt` pins only `pytest>=8.0` and `pytest-cov>=4.0`
- No dependency audit possible without a manifest

### Technical debt

- `local_extractor.py` (45 KB) and `local_extractor_v2.py` at repo root are noted as "internal orchestrator" but not inside the `extractor/` package — creates an awkward import cycle workaround via `__getattr__` in `extractor/__init__.py`
- Scratch / debug files committed to repo root: `debug_*.png`, `*_annotated.png`, `1.jpg` through `7.jpg`, `MCQE_crop.png`, `ARCC_crop.png`, plus `observations.txt`, `orders.json`, `orders5.json`, `orders_lite.json`
- `local_extractor_v2.py` suggests an in-progress refactor that may conflict with the stable `0.1.0` API contract
- No `pyproject.toml` → no package metadata, no version anchor for tooling

### Operational

- CI is active and two-tiered — healthy signal
- No lint CI step — code quality relies entirely on author discipline
- No publish/release pipeline — package is source-only (`pip install -e .`) with no PyPI or registry workflow

## Integration Plan

### Roles that apply

- `tech-lead` (always)
- `backend-engineer` (pure Python library, domain logic in `extractor/`)
- `platform-engineer` (CI pipeline work needed — lint step, publish pipeline)
- `qa-engineer` (verify ACs on merged PRs — especially the two-tier OCR test gate)

### Workflows that kick in

- [x] PR workflow (`.claude/rules/pr-workflow.md`) — every change goes through a PR
- [x] AgDR for technical decisions
- [x] Code Reviewer agent on every PR
- [ ] Security Reviewer agent on first pass and high-risk PRs
- [ ] `/audit-deps` on adoption and monthly thereafter

### Hooks to enable

- [x] `block-git-add-all`
- [x] `block-main-push`
- [x] `validate-branch-name`
- [x] `validate-pr-create`
- [x] `pre-push-gate`
- [x] `check-secrets`

### CI templates to copy in

- [ ] `golden-paths/pipelines/security.yml`
- [ ] `golden-paths/pipelines/pr-title-check.yml`
- Note: `golden-paths/pipelines/ci.yml` (TypeScript-oriented) does not apply — keep the existing Python-native `test.yml`; add lint and security as separate jobs

### Registry entry

```yaml
- name: xadvisor-ocr
  repo: OmarElaraby26/xadvisor-ocr
  workspace: workspace/xadvisor-ocr
  docs: projects/xadvisor-ocr
  status: handover
  roles:
    - tech-lead
    - backend-engineer
    - platform-engineer
    - qa-engineer
```

## Next Steps

1. ~~Add `pyproject.toml` with package metadata, production dep pinning, and tool config — the package cannot be installed as documented without it; this is a blocker for any consumer onboarding~~ → Filed as [#1](https://github.com/OmarElaraby26/xadvisor-ocr/issues/1)
2. ~~Add lint baseline — add `ruff` to `pyproject.toml` and a `ruff check` step to CI so code quality is mechanically enforced, not author-only discipline~~ → Filed as [#2](https://github.com/OmarElaraby26/xadvisor-ocr/issues/2)
3. ~~Move `local_extractor.py` into the `extractor/` package — the current root-level placement creates an import-cycle hack in `__init__.py`; resolve `local_extractor_v2.py` direction (promote or discard) before the move~~ → Filed as [#3](https://github.com/OmarElaraby26/xadvisor-ocr/issues/3)
4. ~~Clean up repo root — move debug images and scratch scripts to `data/` or `scratch/` (gitignored), remove committed `debug_*.png` / `*_annotated.png` / raw JSON files from root~~ → Filed as [#4](https://github.com/OmarElaraby26/xadvisor-ocr/issues/4)
5. /code-review the most-recent PR on this repo as Rex to calibrate review standards
6. Stakeholder sync with the previous owner to cover context the static read couldn't surface

## Post-Handover Checklist

- [ ] Review this assessment with the previous owner
- [ ] Add `pyproject.toml` (Step 1 above) — required before the first feature PR; no consumer can onboard without it
- [ ] Add ruff + CI lint step (Step 2 above) — schedule in first 2 weeks
- [ ] Add `xadvisor-ocr` to the weekly `/stakeholder-update` rollup
- [ ] Run `/audit-deps xadvisor-ocr` monthly (no pinned deps currently — first run will surface the true version range)

## Open Questions

- What is `local_extractor_v2.py` — is it replacing `local_extractor.py` or exploratory? Determines whether Step 3 is a merge or a discard.
- Is PyPI publication planned, or is the package always consumed via editable install from source?
- Are the root-level debug images (`debug_*.png`, `*_annotated.png`) needed for reproducibility or safe to gitignore?
- PROPOSAL.md in the root — is this a spec-in-progress that should move to `projects/xadvisor-ocr/` or a scratchpad?
