# Git Conventions

## Branch Naming

Format: `{type}/{TICKET-ID}-{description}`

Examples:

- `feature/ABC-123-add-auth`
- `fix/GH-45-login-bug`
- `docs/ENG-99-update-readme`

**Types**: `feature`, `fix`, `refactor`, `chore`, `docs`, `test`, `spike`, `ci`, `build`, `perf`

The `TICKET-ID` should reference an issue in the project's own GitHub repo. Default format: `#58` or `GH-58`. The validators in `.claude/hooks/` also accept any uppercase tracker prefix (e.g. `ABC-123`) for teams using Linear, Jira, or similar — but the ApexYard default is per-project GitHub Issues, with one repo's issues never crossing into another repo's PRs.

## PR Title Format

Must match: `type(TICKET): description` or `type(TICKET)!: description` (breaking change)

Regex: `^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|spike)\(([A-Z]+-[0-9]+|#[0-9]+)\)!?:`

- One ticket ID per PR title — multi-ticket titles like `fix(ABC-1,2,3):` are rejected
- GitHub Issues use `#XX` format: `fix(#58): description`
- Breaking changes use `!` before the colon: `feat(#58)!: remove deprecated v1 endpoints`

## Commit Message Format

```
type: subject
type!: subject (breaking change)
type(scope)!: subject (breaking change with scope)

- Detailed change 1
- Detailed change 2

Refs #123
```

**Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`

## Issue references — `Refs` vs `Closes`

`Refs #N` is the **default** issue reference for any PR or commit that touches a ticket. It links the PR to the issue WITHOUT auto-closing it on merge, which routes the ticket through the mandatory QA gate (workflows/sdlc.md § Phase 5 — Salim verifies every AC, applies `qa-passed`, then closes).

`Closes #N` / `Fixes #N` / `Resolves #N` are auto-close keywords — GitHub closes the linked issue automatically when the PR merges. **Reserved for issues that carry an exempt label**:

| Label | Use |
|-------|-----|
| `chore` | Infrastructure / tooling / config; no user-facing AC |
| `docs` | Documentation only |
| `spike` | Hypothesis-driven, time-boxed exploration |
| `infra` | Infra-class work (CI / deploy / monitoring) |
| `qa-bypass` | Catch-all exemption; use sparingly |

If an issue does NOT carry one of those labels and your PR uses `Closes` (or a synonym), the PR-create gate `block-closes-without-exempt-label.sh` blocks the operation. Switch to `Refs #N` (preferred) OR apply an exempt label to the issue first.

The exempt set and keyword list are configurable in `.claude/project-config.json`:

- `.qa.exempt_labels[]` — labels that allow auto-close
- `.qa.autoclose_keywords[]` — keywords that trigger the gate

## File Staging

**NEVER** use `git add -A`, `git add .`, or `git add --all`. Always add specific files:

```bash
git add src/specific-file.ts
```

This is enforced by the `block-git-add-all.sh` hook.

## No Direct Main

Every change must go through a PR. Zero exceptions. No commits directly to `main`/`master`. Enforced by the `block-main-push.sh` hook.

## No Hardcoded Secrets

No API keys, passwords, tokens, or credentials in code. Use environment variables. Patterns to avoid:

- `api_key=`, `password=`, `secret=`, `token=`
- Cloud account IDs and ARNs
- Database connection strings
- Private keys or certificates

Enforced by the `check-secrets.sh` hook.
