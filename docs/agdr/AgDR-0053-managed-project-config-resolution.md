# Managed-project config resolution — workspace overrides ops-fork overrides defaults

> In the context of `OmarElaraby26/apexyard#11`, facing the bug that `block-merge-on-red-ci.sh` reads `.ci.require_to_exist` from `<git toplevel>/.claude/project-config.json` (which silently SKIPS when CWD is a workspace clone that doesn't ship `_lib-read-config.sh`), so any project-scoped flag set in `workspace/<name>/.claude/project-config.json` is dead config, I decided to **(a)** patch `_lib-read-config.sh` to layer workspace config on top of ops-fork override on top of defaults, **(b)** patch `block-merge-on-red-ci.sh` to source the lib via `$(dirname "$0")/_lib-read-config.sh` (the wrapper in settings.json already guarantees `$0` is an ops-fork-absolute path) so the lib loads regardless of CWD, to achieve project-scoped flags that actually take effect when the operator follows the runbook's "commit `.claude/project-config.json` inside the managed project" guidance, accepting that the three-layer merge adds one extra jq invocation per config read on managed-project paths (cached per-process, so amortised cost is negligible) and that ambiguity arises if the operator runs `gh pr merge` from an unrelated CWD (e.g. `~`) — that case falls back to "ops-fork override only", matching the pre-fix behaviour for non-managed CWDs.

## Context

PR #130 in `OmarElaraby26/kt-sdk` followed `docs/runbooks/free-tier-private-ci-enforcement.md` § Phase 4 and committed `{"ci": {"require_to_exist": true}}` to `workspace/kt-sdk/.claude/project-config.json`. Salim re-audit (post-merge) ran `config_get_or '.ci.require_to_exist' 'false'` from both CWD shapes:

- From `workspace/kt-sdk/`: `git rev-parse --show-toplevel` = workspace clone; `[ -f "$REPO_ROOT/.claude/hooks/_lib-read-config.sh" ]` = false (workspace clones don't ship hook libs); config read SKIPPED; default `false` returned.
- From ops fork root: `git toplevel` = ops fork; lib loads; reads ops fork's `.claude/project-config.json` which doesn't exist; defaults `false` returned.

Net effect: the flag never fires. The merge gate's "no checks reported → BLOCK" path is dead. Phase 4.5 smoke "passed" via the existing red-CI block (pending checks were reported, not "no checks reported"), giving false confidence that the strict-missing-CI gate was in effect.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **A. Hook self-loads lib via `dirname $0` + lib gains workspace-config layer** | Operator's existing `workspace/<name>/.claude/project-config.json` (per runbook) just works; minimal hook diff; reuses existing `_config_repo_root` walk-up; transparent to other hooks that already use the lib | Three-layer merge (defaults + ops-fork + workspace) adds one extra jq invocation when CWD is in a workspace; ambiguity if CWD is unrelated (falls back to ops-fork only — same as pre-fix behaviour, so no regression) |
| B. Centralise project-scoped flags in `apexyard.projects.yaml` per-project entry | Single source of truth; registry already read by other hooks | Mixes routing (workspace/docs paths) with feature flags (ci, qa, tracker); schema change for the registry; existing `apexyard.projects.yaml.example` would need an extension; every project-scoped flag the framework grows would land in the registry, ballooning a file meant for project enumeration |
| C. Hook detects PR target repo, looks up workspace via registry | Most "correct" from the model's POV (PR-target-driven, not CWD-driven) | Requires `gh pr view --json headRepository` for every merge attempt; extra round-trip; harder to test (needs mocking the gh shape); two-place change (hook AND lib) |
| D. Do nothing — document the limitation in the runbook | Zero code change | Operators will continue to think the flag is live; bug-disguised-as-feature; runbook becomes lying-by-omission |

## Decision

Chosen: **A** — workspace-config-aware lib + hook self-loads via `dirname $0`.

Rationale:
- Matches operator mental model: project-scoped config lives in the project's repo (per the runbook).
- Smallest diff that fixes the bug end-to-end. Two files changed (`_lib-read-config.sh`, `block-merge-on-red-ci.sh`), one new test case added.
- Doesn't pollute the registry schema (rejected option B's main downside).
- Doesn't add network/gh round-trips per merge (rejected option C's main downside).
- The CWD-driven nature is acceptable because the runbook's normal flow has the operator inside `workspace/<name>/` when running `gh pr merge` for that project. If the operator runs from elsewhere, fallback to ops-fork-only behaviour is the same as pre-fix — no regression.

## Implementation

### `_lib-read-config.sh` (modified)

`_config_load` extended to a three-layer merge:

1. `<ops_root>/.claude/project-config.defaults.json` (framework defaults)
2. `<ops_root>/.claude/project-config.json` (ops-fork override; existing layer)
3. `<workspace_dir>/.claude/project-config.json` (NEW — workspace override; only when CWD's git toplevel is inside a registered workspace under `<ops_root>/workspace/<name>/`)

Workspace detection: walk from `$PWD` to git toplevel; if the resulting path is `<ops_root>/workspace/<name>` (any registered project name from `apexyard.projects.yaml`), use `<workspace>/.claude/project-config.json` as layer 3 when present.

When CWD is not inside any registered workspace, the three-layer merge degenerates to the existing two-layer merge — no behaviour change for ops-fork-rooted invocations.

### `block-merge-on-red-ci.sh` (modified)

Replace the CWD-derived lib lookup:

```diff
- REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
- if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.claude/hooks/_lib-read-config.sh" ]; then
-   . "$REPO_ROOT/.claude/hooks/_lib-read-config.sh"
+ HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
+ if [ -f "$HOOK_DIR/_lib-read-config.sh" ]; then
+   . "$HOOK_DIR/_lib-read-config.sh"
   REQUIRE_CI_TO_EXIST=$(config_get_or '.ci.require_to_exist' 'false' 2>/dev/null)
fi
```

This works because the wrapper in `.claude/settings.json` walks up to find the ops fork's `.apexyard-fork` (v2) or `onboarding.yaml` (v1) anchor and then `exec`s the hook via its ops-fork-absolute path. `$0` is therefore guaranteed to be the ops-fork copy of the hook, and `dirname $0` is the ops fork's `.claude/hooks/` directory.

### Tests

`test_block_merge_on_red_ci.sh` gains a Case 7 that constructs the bug shape:

```
make_workspace_sandbox() {
  # Create an ops-fork sandbox at <sb>/ops-fork/ AND a workspace sandbox at
  # <sb>/ops-fork/workspace/<name>/. The workspace ships NO hook libs (matches
  # real managed-project clones). Register <name> in <sb>/ops-fork/apexyard.projects.yaml.
  # Write project-config.json at the workspace level with ci.require_to_exist=true.
  # Run the hook with PWD=<workspace>; expect exit 2 ("no CI checks reported") on
  # a gh mock that reports "no checks reported".
}
```

Asserts: flag IS read from the workspace's project-config.json even when CWD's git toplevel doesn't have `_lib-read-config.sh`.

### Runbook

`docs/runbooks/free-tier-private-ci-enforcement.md` § Phase 4 — replace "available since framework versions including .ci.require_to_exist" with a pointer to this AgDR + the apexyard version that ships the resolution fix (TBD post-merge).

### kt-sdk#129 re-verification

After this PR merges, re-open Phase 4.5 smoke with the framework fix in place:

```bash
# Disable the workflow file in a throwaway branch
git checkout -b chore/test-flag-actually-fires
git rm .github/workflows/ci.yml && git commit -m "test: temporarily remove workflow"
git push -u origin chore/test-flag-actually-fires
gh pr create ...
# Expect: gh pr checks reports "no checks reported"
gh pr merge <pr>
# Expect: BLOCK with "no CI checks reported" message — proving the flag fires
```

## Consequences

- **`.ci.require_to_exist=true` in a managed-project workspace IS now honoured** — assuming operator runs `gh pr merge` from inside the workspace (or from ops fork with the flag also set there).
- **Other project-scoped flags benefit automatically** — any future flag the framework grows that wants per-project overrides can be set in `workspace/<name>/.claude/project-config.json` and will be picked up without further framework changes.
- **Three-layer merge cost** — one extra jq invocation per `config_load`. Cached per-process, so amortised cost is near-zero.
- **Workspace detection adds ~10 LOC** to the lib — pays for itself by closing the dead-config bug.
- **CWD ambiguity** — operator running from an unrelated CWD (e.g. `~`) gets ops-fork-only behaviour. Acceptable because (a) this is unchanged from the pre-fix state, (b) the runbook directs operators to work inside `workspace/<name>/`.

## Reversibility

- Revert the lib + hook patches in a single revert PR. Behaviour returns to pre-fix (ops-fork-only config read; workspace files ignored).
- The runbook and AgDR-0019 (in kt-sdk) cite this AgDR; reverting requires removing those citations or updating them to point at an alternative resolution.

## Artifacts

- This AgDR
- Tracking issue: `OmarElaraby26/apexyard#11`
- This PR (resolves the framework bug)
- Source observation: `OmarElaraby26/kt-sdk#129` Salim re-audit (comment 4556436462) — discovered the dead-config bug
- Re-verification target: `OmarElaraby26/kt-sdk#129` Phase 4.5 smoke after this PR lands
