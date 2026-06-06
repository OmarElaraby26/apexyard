---
id: AgDR-0005
timestamp: 2026-06-06T15:49:00Z
agent: claude
model: claude-sonnet-4-6
trigger: user-prompt
status: executed
---

# AgDR-0005 — xadvisor FastAPI Wrap: M1 Domain Spec

> In the context of the xadvisor FastAPI Wrap MVP initiative (xadvisor#118), facing the need to fix the strategic domain shape before any persistence, API, or auth milestone begins, I decided to lock seven domain decisions now — aggregates, strategy ownership, portfolio lifecycle, backtest binding, position derivation, tenancy, and JWT claims — to achieve a single source of truth that every downstream milestone reads without re-litigation, accepting that these decisions are expensive to reverse after M2/M3 begin.

## Context

The FastAPI Wrap initiative adds a clean-architecture HTTP layer over the existing `egxdata` core. Before writing a single model or route, the domain shape must be frozen: which entities are aggregates, who owns strategies, how portfolios change state, where positions come from, and what identity claims flow through the JWT. Getting this wrong at M2 or M3 forces a migration and a broken backtest history.

The seven decisions below were identified during initiative planning and are ordered by their blast radius: decisions that block more milestones come first.

## Decisions

### D1 — User is the root aggregate

**Decision**: Every major entity (`Portfolio`, `Transaction`, `Backtest`, `Strategy`) traces back to a `User` via an `owner_id` foreign key. User is the tenancy boundary.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **User as root (chosen)** | Clean multi-tenancy; repository scoping by `owner_id` is straightforward; aligns with authorization model | Every table needs an extra FK column |
| Organisation as root | Supports team portfolios | Premature — MVP is single-user; adds schema complexity with no immediate payoff |
| No explicit owner on entities | Simpler schema | Auth becomes ad-hoc and leaky; cannot scope queries safely |

**Decision**: User as root aggregate. Every repository method scopes by `owner_id` at the DAO layer. Organisation/team tenancy is deferred past MVP.

---

### D2 — Strategy is system-owned and immutable for MVP

**Decision**: For MVP, strategies are system-authored, version-stamped, and immutable once published. The `Strategy` table records `(id, version, name, parameters, created_at)`; no user-authored strategies exist yet.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **System-owned + immutable (chosen)** | Predictable backtest reproducibility; no user-strategy CRUD surface needed at MVP | User creativity deferred; strategies cannot be personalised |
| User-created strategies | Maximum flexibility | Significant additional scope (validation, ownership, versioning UI); risks MVP scope creep |
| Mutable system strategies | Simpler versioning | Backtests become ambiguous when strategy parameters change mid-run |

**Decision**: System-owned immutable strategies only. Strategy versioning is a string `v1`, `v1.1`, etc. User-created strategies are post-MVP. The system seeds strategy records on boot (M3).

---

### D3 — Portfolio is a capital container with lifecycle states ACTIVE / ARCHIVED

**Decision**: A `Portfolio` row holds `(id, owner_id, strategy_id, name, status, created_at, archived_at)` where `status ∈ {ACTIVE, ARCHIVED}`. Archiving is a soft-delete — a portfolio cannot be hard-deleted because its transaction history is the source of truth.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **ACTIVE / ARCHIVED soft-delete (chosen)** | Preserves history; clean API surface for "my portfolios"; audit-safe | `archived_at` NULL vs non-NULL must be handled consistently |
| Hard delete | Simpler schema | Destroys transaction history; illegal in any future audit context |
| Additional states (SUSPENDED, LIQUIDATED) | More expressive | Premature; adds state-machine complexity with no immediate use |

**Decision**: Two states: ACTIVE and ARCHIVED. Archived portfolios remain readable (history) but cannot receive new transactions.

---

### D4 — Backtest is bound to `strategy_id`, not `portfolio_id`

**Decision**: `Backtest` has `(id, owner_id, strategy_id, parameters_snapshot, result_json, created_at)`. No `portfolio_id` FK.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **Bound to `strategy_id` (chosen)** | Backtests are a property of a strategy, not a portfolio; a user can backtest a strategy before creating a portfolio | Slightly less intuitive for users who think of backtests per-portfolio |
| Bound to `portfolio_id` | Aligns with "I want to test this portfolio's strategy" mental model | A portfolio may change strategies; historical backtest becomes misleading; cannot backtest before portfolio exists |
| Dual FK to both | Flexible | Nullable FKs introduce consistency bugs |

**Decision**: Backtest binds to `strategy_id`. A `parameters_snapshot` JSONB column captures the exact parameter set at run time so the result is reproducible even when strategy parameters evolve.

---

### D5 — Transactions are the source of truth; positions are derived projections

**Decision**: The `Transaction` table is append-only. Current portfolio positions are never stored; they are computed by summing the transaction log filtered to the portfolio. No `Position` table exists at MVP.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **Transaction log as source of truth (chosen)** | Perfect audit trail; no sync bugs between position cache and transaction log; trivial point-in-time queries | Every position read requires a `SUM` over transactions (acceptable at MVP scale) |
| Position table as materialised cache | Fast reads | Must be kept in sync with transactions; two sources of truth; sync bugs |
| Event-sourcing with explicit event types | Maximum auditability | Significant over-engineering for MVP; adds projection infrastructure |

**Decision**: Append-only `Transaction` log. Positions are computed on read. If read performance becomes a concern post-MVP, a materialised `Position` cache can be added as a read-model without changing the write model.

---

### D6 — Every major table carries `owner_id` from day one

**Decision**: `Portfolio`, `Transaction`, `Backtest` all carry `owner_id UUID NOT NULL REFERENCES users(id)`. This is enforced at schema migration time, not at application time.

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **`owner_id` on all tables (chosen)** | Defense-in-depth; repository layer can always add `WHERE owner_id = :caller`; never retrofitted | Slightly redundant (Portfolio → Transaction has an implicit owner via Portfolio FK) |
| `owner_id` only on Portfolio | Fewer columns | Transactions must always be looked up via Portfolio join; direct transaction query is unsafe |
| Application-level-only scoping | No DB column overhead | If a query bypasses the application layer (migration, ad-hoc query, future direct DB read), tenancy is invisible |

**Decision**: `owner_id` on every major table. The redundancy is intentional — it makes raw SQL queries and future reporting trivially safe.

---

### D7 — JWT claims shape: `{sub, email, iat, exp}`

**Decision**: First-party JWTs issued by the xadvisor API carry exactly these claims:

```json
{
  "sub": "<uuid>",
  "email": "user@example.com",
  "iat": 1717000000,
  "exp": 1717003600
}
```

`sub` is the internal `users.id` (UUID), not the Google subject. Mapping from Google `sub` to internal `sub` happens at login (M6).

**Options considered**:

| Option | Pros | Cons |
|--------|------|------|
| **Minimal claims + internal `sub` (chosen)** | Small JWT; `sub` is always the internal user ID regardless of OAuth provider; adding claims later is a version bump | `email` is technically redundant (server can look up by `sub`); included for UX convenience only |
| Include Google `sub` as `google_sub` | Provider ID available in JWT | Locks API clients to Google-specific semantics; breaks if a second OAuth provider is added |
| Rich claims (name, picture, roles) | Fewer round-trips for clients | JWT grows; any profile change invalidates issued tokens |
| Opaque session token instead of JWT | No claims-exposure risk | Requires session store; stateful; doesn't compose with mobile clients |

**Decision**: Minimal JWT with `{sub, email, iat, exp}`. `sub` = internal `users.id`. Adding claims in a future version is a breaking change and requires a JWT version bump — that gate is documented here so future-us doesn't add claims casually.

---

## Summary table

| # | Decision | Impact |
|---|----------|--------|
| D1 | User is root aggregate; `owner_id` on everything | Tenancy model for all milestones |
| D2 | Strategies are system-owned + immutable for MVP | M2 strategy abstraction shape; M3 seed-on-boot |
| D3 | Portfolio states: ACTIVE / ARCHIVED (soft-delete only) | M3 schema + M7 portfolio API |
| D4 | Backtest binds to `strategy_id`, not `portfolio_id` | M3 schema; backtest result reproducibility |
| D5 | Transactions are source of truth; positions are derived | M3 schema; M8 ledger API |
| D6 | `owner_id` on every major table at schema level | M3 schema; M4.5 authorization layer |
| D7 | JWT: `{sub=internal_uuid, email, iat, exp}` | M4 user domain; M6 OAuth + JWT issue |

## Consequences

- **M2 (Strategy Abstraction)**: strategy interface must match immutable + versioned shape from D2. The `strategy_id` FK in Portfolio and Backtest references this catalog.
- **M3 (Persistence + Postgres)**: schema must include `owner_id` on `Portfolio`, `Transaction`, `Backtest` (D6); Portfolio status enum (D3); no `Position` table (D5); Strategy seed-on-boot (D2).
- **M4 (User/Auth Domain)**: `JWTClaims` value object is `{sub: UUID, email: str, iat: int, exp: int}` per D7. No additional claims without a version bump.
- **M4.5 (Authorization Layer)**: policies scope on `owner_id`; D6 makes this safe at DAO layer without a JOIN.
- **M6 (Google OAuth)**: Google `sub` maps to internal `users.id`; issued JWT carries internal `sub`, not Google `sub` (D7).
- **M7/M8 (Portfolio + Ledger API)**: portfolio CRUD must enforce ACTIVE/ARCHIVED state machine (D3); transaction write path is append-only (D5).
- **Post-MVP scope explicitly excluded**: user-created strategies (D2 reversal), organisation tenancy (D1 extension), Position materialised cache (D5 extension), richer JWT claims (D7 extension) — all require explicit AgDR before starting.

## Artifacts

- [xadvisor#118](https://github.com/OmarElaraby26/xadvisor/issues/118) — the milestone ticket this AgDR closes
- [xadvisor FastAPI Wrap initiative](../../../projects/xadvisor/initiatives/xadvisor-fastapi-wrap.md) — full dependency graph + milestone specs
- Downstream: AgDR-0005 is referenced by M2 (#119), M3 (#122), M4 (#120), M5 (#121) tickets as the domain-spec authority
