# Runbook: enforce "no merge without green CI" on a free-tier private GitHub repo

> Audience: a future LLM session (Claude / Sonnet / similar) running ApexYard against a new project. Follow top-to-bottom. Each step is a discrete checkpoint with verify commands.
>
> Goal: end state where (a) CI runs on every PR, (b) `gh pr merge` is mechanically blocked when CI is red OR missing, (c) operator's machine catches lint/test failures pre-push, (d) all of it costs zero dollars.
>
> Constraints assumed:
>
> - Repo is **private** on a personal GitHub account (no GitHub Pro, no free org)
> - Server-side branch protection is therefore NOT available (Pro-only on personal-account private repos)
> - Project uses npm-style tooling (adjust `npm` → `pnpm` / `yarn` / `bun` where applicable)
> - ApexYard ops fork is at `<OPS_FORK>` (e.g. `~/work/<your-project>/apexyard`)
> - Managed-project workspace is at `<OPS_FORK>/workspace/<PROJECT>/`
> - GitHub repo is `<OWNER>/<REPO>`

---

## Decision tree (read this first)

| Constraint mix | Path |
|---|---|
| Private, personal acct, free tier | **THIS RUNBOOK** — self-hosted runner + client-side hook + pre-push |
| Private, free org | Skip the hook patch; use server-side branch protection directly (free orgs get it) |
| Public repo, free tier | Use `runs-on: ubuntu-latest` (free unlimited) + server-side branch protection |
| Private, willing to pay | GitHub Pro $4/mo → server-side branch protection |

If the operator's constraints match row 1, continue.

---

## Phase 0 — prerequisites checklist

```bash
# Verify ApexYard ops fork is set up + on main
cd <OPS_FORK>
git status                                    # should be clean
git log --oneline -1                          # should be on a recent commit
ls .claude/hooks/block-merge-on-red-ci.sh     # must exist (framework version)

# Verify the workspace clone exists for <PROJECT>
ls workspace/<PROJECT>/.git                   # must exist
cd workspace/<PROJECT>
npm install                                   # so node_modules exist for tests + husky
```

If any of these fails, run `/setup` and `/handover <PROJECT>` first.

---

## Phase 1 — add CI workflow + npm scripts in the managed project

### 1.1. Verify the project has lint / test / typecheck scripts

```bash
cd <OPS_FORK>/workspace/<PROJECT>
python3 -c "import json; print(list(json.load(open('package.json'))['scripts'].keys()))"
```

If `lint`, `test`, `typecheck` are missing, file a separate ticket FIRST to add them. CI cannot enforce what doesn't run.

For Expo/RN projects the typical wiring:

```json
{
  "scripts": {
    "test": "jest",
    "lint": "eslint src tests",
    "typecheck": "tsc --noEmit"
  }
}
```

ESLint config: `eslint.config.js` extending `eslint-config-expo/flat` (for Expo), `eslint-config-next` (for Next), etc.

### 1.2. Create the CI workflow

Path: `<OPS_FORK>/workspace/<PROJECT>/.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: lint + typecheck + test
    runs-on: [self-hosted, linux, x64]
    timeout-minutes: 10
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          # cache: 'npm' intentionally omitted. On self-hosted runners the
          # node_modules dir persists between jobs, so the cache action's
          # Post step adds 5-10 min of overhead uploading a tarball that
          # nobody downloads back. Without it, the build is ~30s end-to-end.

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Typecheck
        run: npm run typecheck

      - name: Test
        run: npm test
```

**Key parameters to tune per project:**

| Token | Meaning | Common values |
|-------|---------|---------------|
| `runs-on` | Runner label set | `[self-hosted, linux, x64]` (this runbook) / `ubuntu-latest` (GH-hosted) |
| `node-version` | Node major | match project's runtime requirement (`20` for Expo SDK 54+) |
| `permissions.contents` | Token scope | `read` (workflow only checks out, no API writes) |
| `concurrency.cancel-in-progress` | Cancel superseded runs | `true` for solo / small teams |

### 1.3. Write the AgDR (apexyard requires for CI/CD files)

Path: `<OPS_FORK>/workspace/<PROJECT>/docs/agdr/AgDR-NNNN-ci-design.md`

Use `templates/agdr.md` from the apexyard fork. Cover at minimum:

- Why self-hosted vs GH-hosted (billing / cost / privacy)
- Why single-job sequential vs parallel matrix
- Why this Node version
- Component-test / e2e-test exclusions if any (and the follow-up ticket for them)
- **Operator runbook** subsection: how to set up the self-hosted runner (see Phase 2 below — link to it from here)

Reference: `<OPS_FORK>/workspace/beProductive/docs/agdr/AgDR-0002-ci-design.md` is a worked example.

### 1.4. Commit + open PR

Follow the standard ApexYard flow:

1. `/start-ticket <OWNER>/<REPO>#<N>` (issue you filed for "add CI workflow")
2. Create branch: `git checkout -b chore/GH-<N>-add-ci-workflow`
3. Add `ci.yml` + `AgDR-NNNN`
4. Commit, push
5. `gh pr create` with `<!-- agdr: not-applicable -->` only if no architectural choice involved (rare for CI; usually you need the AgDR)
6. Invoke `code-reviewer` agent (Rex)
7. Wait for explicit per-PR CEO merge approval
8. `/approve-merge <PR#>`

Verify: PR landed. Workflow exists on main but CI **cannot run yet** — no self-hosted runner installed.

---

## Phase 2 — install a self-hosted GitHub Actions runner

The operator must do this on whichever machine will execute CI jobs. Most adopters point this at their primary dev machine (laptop) or a small always-on box (Raspberry Pi, $5 VPS, NUC).

### 2.1. Fetch runner

```bash
# Get the latest version tag
LATEST=$(curl -sL https://api.github.com/repos/actions/runner/releases/latest \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])")
VERSION="${LATEST#v}"

# Detect arch + OS (this runbook covers Linux x86_64)
mkdir -p ~/actions-runner-<PROJECT> && cd ~/actions-runner-<PROJECT>

curl -sLO "https://github.com/actions/runner/releases/download/${LATEST}/actions-runner-linux-x64-${VERSION}.tar.gz"
tar xzf "actions-runner-linux-x64-${VERSION}.tar.gz"
```

### 2.2. Get a registration token (one-time, expires in ~1 hour)

```bash
APEXYARD_ALLOW_RAW_TICKET_CREATE=1 \
  gh api -X POST repos/<OWNER>/<REPO>/actions/runners/registration-token --jq '.token'
```

(The env var is needed because the `gh api repos/` pattern matches ApexYard's `require-skill-for-issue-create.sh` hook — false positive for read-only registration calls.)

Copy the printed token. Single-use, single-machine.

### 2.3. Configure runner

```bash
cd ~/actions-runner-<PROJECT>
./config.sh \
  --url https://github.com/<OWNER>/<REPO> \
  --token <TOKEN_FROM_2.2> \
  --name <PROJECT>-runner-1 \
  --labels self-hosted,linux,x64 \
  --work _work \
  --unattended
```

Expected output: `√ Connected to GitHub`, `√ Runner successfully added`, `√ Settings Saved.`

### 2.4. Start runner

**Foreground (first-time test)**:

```bash
./run.sh
# Expect: "Listening for Jobs"
```

Ctrl-C to stop.

**Background (long-running)**:

```bash
# Option A: nohup (survives current shell session)
nohup ./run.sh > runner.log 2>&1 &
echo $! > runner.pid

# Option B: systemd service (survives reboots) — RECOMMENDED for primary runner
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

### 2.5. Verify runner online

```bash
APEXYARD_ALLOW_RAW_TICKET_CREATE=1 \
  gh api repos/<OWNER>/<REPO>/actions/runners \
  --jq '.runners[] | "\(.name) \(.status) busy=\(.busy)"'
# Expect: "<PROJECT>-runner-1 online busy=false"
```

### 2.6. Trigger first run

Push any commit, or re-run the most recent CI run:

```bash
APEXYARD_ALLOW_RAW_TICKET_CREATE=1 \
  gh run rerun $(gh api repos/<OWNER>/<REPO>/actions/runs?per_page=1 --jq '.workflow_runs[0].id') \
  -R <OWNER>/<REPO>

# Poll for completion
until APEXYARD_ALLOW_RAW_TICKET_CREATE=1 \
      gh api "repos/<OWNER>/<REPO>/actions/runs?per_page=1" \
      --jq '.workflow_runs[0].status' | grep -q completed; do
  sleep 10
done

APEXYARD_ALLOW_RAW_TICKET_CREATE=1 \
  gh api "repos/<OWNER>/<REPO>/actions/runs?per_page=1" \
  --jq '.workflow_runs[0] | "status=\(.status) conclusion=\(.conclusion)"'
# Expect: status=completed conclusion=success
```

---

## Phase 3 — add husky pre-push hook (local belt-and-braces)

Catches failures before they reach the runner. Defense in depth even when the runner is offline.

### 3.1. Install + init

```bash
cd <OPS_FORK>/workspace/<PROJECT>
npm install --save-dev husky
npx husky init
# Creates .husky/_ + .husky/pre-commit + adds "prepare": "husky" to package.json
```

### 3.2. Replace `pre-commit` with `pre-push`

```bash
rm .husky/pre-commit

cat > .husky/pre-push <<'EOF'
#!/usr/bin/env sh
# Pre-push gate — mirror CI so failures don't reach the remote runner.
set -e

echo "[pre-push] lint..."
npm run lint

echo "[pre-push] typecheck..."
npm run typecheck

echo "[pre-push] test..."
npm test

echo "[pre-push] ok"
EOF

chmod +x .husky/pre-push
```

### 3.3. Harden `prepare` script

Edit `package.json`:

```diff
- "prepare": "husky"
+ "prepare": "husky || true"
```

Reason: `husky` binary won't exist on `npm ci --production` (no devDependencies). The `|| true` no-ops cleanly instead of failing the install.

### 3.4. Verify hook fires

```bash
# Direct invocation (simulates git push trigger)
.husky/_/pre-push HEAD origin
# Expect to see [pre-push] lint... / typecheck... / test... / ok
```

### 3.5. Commit + PR via standard ApexYard flow

Same shape as Phase 1.4.

---

## Phase 4 — enable the ApexYard "strict missing-CI = block" flag

ApexYard's `block-merge-on-red-ci.sh` defaults to "no checks = pass with NOTE". Free-tier private repos need the opposite — "no checks = BLOCK". Two pieces of framework state must both be in place for the flag to fire on a managed project:

| Framework piece | Adds | Apexyard ref |
|-----------------|------|---------------|
| `.ci.require_to_exist` flag in defaults | Hook reads the flag and treats `true` as "no checks = BLOCK" | PR #6 |
| Workspace-config-aware lib (`_lib-read-config.sh` three-layer merge + hook `dirname $0` self-locate) | Hook actually reads `workspace/<name>/.claude/project-config.json` (the file this runbook tells you to create); pre-#12 the file was committed-but-never-read dead config | PR #12 (AgDR-0053) |

> **Important — `/update` is required for this phase.** Adopters whose apexyard fork is older than commit `5825d38` (`fix(#11)` merge) MUST run `/update` past that point first. Otherwise the flag in step 4.2 will sit in `workspace/<name>/.claude/project-config.json` and be silently ignored — Salim caught this on a real run; see [`AgDR-0053-managed-project-config-resolution.md`](../agdr/AgDR-0053-managed-project-config-resolution.md).

### 4.1. Confirm the apexyard fork ships both pieces

```bash
cd <OPS_FORK>

# Piece 1: the flag exists in defaults (PR #6)
grep require_to_exist .claude/project-config.defaults.json
# Expect: "require_to_exist": false (with a _comment line)

# Piece 2: the lib reads workspace config (PR #12 / AgDR-0053)
grep -l _config_workspace_overrides_file .claude/hooks/_lib-read-config.sh
# Expect: .claude/hooks/_lib-read-config.sh
# If empty: framework is pre-#12 — flag will not fire. Run /update first.
```

If either grep is empty, the operator's apexyard fork is out of date. Run `/update` to sync from upstream first.

### 4.2. Add project-config override in the managed project

Path: `<OPS_FORK>/workspace/<PROJECT>/.claude/project-config.json`

```json
{
  "_comment": "Project-level ApexYard config. Shallow-merged on top of <OPS_FORK>/.claude/project-config.defaults.json. See docs/agdr/AgDR-NNNN-require-ci-to-exist.md for context.",
  "ci": {
    "require_to_exist": true
  }
}
```

### 4.3. Write AgDR

Path: `<OPS_FORK>/workspace/<PROJECT>/docs/agdr/AgDR-NNNN-require-ci-to-exist-flag.md`

Cover:

- Context (free-tier private repo, server-side branch protection unavailable)
- Options table (transfer to free org / pay for Pro / public repo / cron audit / **THIS option**)
- Decision: client-side `.ci.require_to_exist=true`
- Consequence: bypass surface remains (web UI merge, direct `gh api .../merge`) — accepted with named justification
- Reversibility: delete the key any time

Reference example: `<OPS_FORK>/workspace/beProductive/docs/agdr/AgDR-0003-require-ci-to-exist-flag.md`

### 4.4. Commit + PR

Standard flow.

### 4.5. Verify enforcement

After the PR merges, the next merge attempt without CI should fail:

```bash
# Disable the runner temporarily to simulate "no CI"
sudo systemctl stop actions.runner.<OWNER>-<REPO>.<PROJECT>-runner-1.service

# Open a tiny PR (e.g. a comment-only commit), wait for CI to queue (it won't complete)
# Then attempt:
gh pr merge <PR#> --repo <OWNER>/<REPO> --squash --delete-branch
# Expect: BLOCKED message naming "no CI checks reported" — hook is working

# Re-enable
sudo systemctl start actions.runner.<OWNER>-<REPO>.<PROJECT>-runner-1.service
```

---

## Phase 5 — operator handoff

Document for the human operator (not the LLM):

1. **Self-hosted runner machine must be online when wanting to merge.** Job queues if runner offline; ApexYard hook will block the merge until a green run lands.
2. **Pre-push hook auto-installs on `npm install`.** Any contributor (= you, for solo) gets it.
3. **Bypass surface for the flag:**
   - GitHub web-UI merge button (not gated by the client-side hook)
   - Direct `gh api .../merge` calls
   - Accepted because solo project; if a team forms, migrate to a free org for server-side enforcement.
4. **Emergency bypass for pre-push:** `git push --no-verify`. Don't make routine.
5. **Emergency bypass for the merge gate:** delete the hook file or set `.ci.require_to_exist: false` in `.claude/project-config.json`. Deliberate, visible, auditable.

---

## End state (verification matrix)

| Mechanism | What it gates | Bypass-able? | Lives in |
|-----------|---------------|--------------|----------|
| GitHub Actions workflow | Every PR + push to main runs lint+typecheck+test | Removing the workflow file (caught by Phase 4) | `<PROJECT>/.github/workflows/ci.yml` |
| Self-hosted runner | Executes the workflow | Runner offline → jobs queue (caught by Phase 4) | Operator's machine |
| ApexYard `block-merge-on-red-ci.sh` | `gh pr merge` blocked on red CI | Web-UI merge, direct `gh api .../merge` | `<OPS_FORK>/.claude/hooks/` |
| `.ci.require_to_exist=true` | `gh pr merge` blocked when no CI run | Same as above | `<PROJECT>/.claude/project-config.json` |
| husky pre-push | `git push` blocked if local lint/test fails | `git push --no-verify` | `<PROJECT>/.husky/pre-push` |

If all five rows are populated, the project has end-to-end "no merge without green CI" enforcement at zero cost on free-tier private GitHub.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| Job runs > 10 min, gets cancelled at `Post Setup Node` | `cache: 'npm'` on self-hosted runner — Post step uploads a tarball the runner doesn't need | Remove `cache: 'npm'` from `setup-node` config (this runbook's Phase 1.2 already does this) |
| `gh api repos/...` blocked by ApexYard hook | `require-skill-for-issue-create.sh` false-positive on read-only API calls | Prefix with `APEXYARD_ALLOW_RAW_TICKET_CREATE=1` (operator-explicit override) |
| Hook reports "BLOCKED" but I want to merge anyway | Strict mode caught a real "no CI" state | Bring runner online + push to trigger a fresh run, or temporarily set `require_to_exist=false` |
| Push succeeds but no `[pre-push]` lines visible | Output got truncated by `tail -N` filtering | Run `.husky/_/pre-push HEAD origin` directly to confirm hook works |
| `gh pr merge` blocked: "no CEO approval marker" | This is the per-PR approval gate firing, not the CI gate | Use `/approve-merge <PR#>` skill (writes the structured marker AND merges in one turn) |

---

## See also

- `<OPS_FORK>/.claude/rules/pr-quality.md` § "No Red CI Before Merge"
- `<OPS_FORK>/.claude/hooks/block-merge-on-red-ci.sh` — the hook source
- `<OPS_FORK>/.claude/project-config.defaults.json` § `ci` — default schema
- `<OPS_FORK>/workspace/beProductive/docs/agdr/AgDR-0002-ci-design.md` — worked example of the CI design AgDR
- `<OPS_FORK>/workspace/beProductive/docs/agdr/AgDR-0003-require-ci-to-exist-flag.md` — worked example of the flag-enablement AgDR
