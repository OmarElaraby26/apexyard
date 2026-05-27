# kt-sdk — Project Docs

Python Knowledge-Tracing SDK. Two-package library (kt-core + kt-models) anyone can drop into their own KT application — no DB, no Redis, no HTTP server, no opinionated infrastructure.

## Owners

- Tech lead: Omar Elaraby
- Status: handover (2026-05-21)

## Links

- Repo: https://github.com/OmarElaraby26/kt-sdk (private)
- Handover assessment: [`handover-assessment.md`](handover-assessment.md)
- Architecture (L2 containers): [`architecture/container.md`](architecture/container.md)
- Architecture decisions (source): https://github.com/OmarElaraby26/kt-sdk/blob/main/agdd.md (12 decisions from the GetNextQuestion work; pending migration to per-file AgDRs)

## Tech stack

- Python ≥ 3.10
- pytest (216 tests as of 2026-05-21)
- torch ≥ 2.1, numpy ≥ 1.24 (kt-models only; kt-core is stdlib-only)
