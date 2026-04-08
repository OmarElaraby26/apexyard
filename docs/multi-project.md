# Multi-Project Mode

ApexStack supports two operating modes. **Multi-project mode is the default**: ApexStack lives in an "ops repo" and governs a portfolio of repos as one organisation. **Single-project mode** is opt-in for the simple case: ApexStack lives inside one repo and governs that repo only. This document covers the multi-project mode in depth — the setup, the registry, the daily workflow, and how to opt back to single-project if you need to.

---

## TL;DR

| | Multi-project (default) | Single-project (opt-in) |
|---|---|---|
| **Number of repos governed** | many | 1 |
| **Where ApexStack lives** | In a separate "ops repo" | Inside the one project repo |
| **Roadmap location** | `projects/<name>/roadmap.md` per project | `ROADMAP.md` at project root |
| **Ideas location** | `projects/ideas-backlog.md` (shared) | `IDEAS.md` at project root |
| **Registry file** | `apexstack.projects.yaml` | None |
| **`/projects` shows** | All projects in the registry | The current repo |
| **`/inbox` shows** | Items across the whole registry | Items in the current repo |
| **Set in `onboarding.yaml`** | `apexstack.mode: multi-project` (default) | `apexstack.mode: single-project` |
| **Best for** | CTO / engineering lead / Chief of Staff with a portfolio | Solo dev, one-product teams |

---

## Why multi-project is the default

Most engineering orgs have more than one repo. Even a "single product" team usually has at least an app repo + an infra repo + a marketing site + maybe a CLI or extension. ApexStack is built around managing that portfolio coherently — one ops repo, one registry, one set of skills that aggregate across everything.

If you actually have **exactly one repo** to govern, single-project mode is the right call — it's simpler and avoids the registry overhead. Set `apexstack.mode: single-project` in `onboarding.yaml` and the same skills scope to the current repo.

---

## When to switch to single-project mode

Switch to single-project (opt out of multi-project) when **all** of these are true:

1. You manage **exactly one** repo
2. You don't see that changing in the foreseeable future
3. You want zero registry overhead

Multi-project mode is otherwise the right default — even if you only have two repos, the registry is one tiny YAML file and the cross-repo skills (`/projects`, `/inbox`, `/status`, `/tasks`) are immediately useful.

---

## Setup

### 1. Pick the ops repo

Decide which repo will be your **ops repo**. Common choices:

- A new dedicated repo (e.g. `your-org/ops`)
- An existing internal-tools repo
- A `meta` repo that already holds your team's playbooks

The ops repo holds:

- The ApexStack rules, skills, and hooks (`.claude/`)
- The registry (`apexstack.projects.yaml`)
- Per-project docs (`projects/<name>/`)
- Optionally, live clones of each managed repo (`workspace/<name>/`)

### 2. Switch the mode

In `onboarding.yaml`, set:

```yaml
apexstack:
  mode: multi-project
```

### 3. Create the registry

Copy `apexstack.projects.yaml.example` to `apexstack.projects.yaml` and edit it. The minimal entry is:

```yaml
version: 1
projects:
  - name: example-app
    repo: your-org/example-app
    docs: projects/example-app
    status: active
```

You can add `workspace`, `roles`, `tier`, `tags`, and `ticket_prefix` later.

### 4. Seed `projects/<name>/`

For each project in the registry, create the docs folder:

```
projects/example-app/
├── README.md      ← project overview, owners, links
└── roadmap.md     ← project-specific roadmap (optional)
```

You can run `/handover example-app` to auto-generate a `handover-assessment.md` and seed the README.

### 5. (Optional) Clone the live working copy

```bash
git clone github.com/your-org/example-app workspace/example-app
```

Add `workspace/*/` to the ops repo's `.gitignore` — live clones have their own remotes and shouldn't be double-tracked.

### 6. Verify

Run:

```
/projects
```

You should see a table with one row per project from the registry. Then:

```
/inbox
/status
/tasks
```

Each should aggregate across all the projects you've registered.

---

## Directory layout

```
my-ops-repo/
├── .claude/                       ← shared rules, skills, hooks, agents
├── apexstack.projects.yaml        ← the registry (multi-project mode marker)
├── onboarding.yaml                ← apexstack.mode: multi-project
│
├── workspace/                     ← LIVE WORKING COPIES (gitignored)
│   ├── README.md
│   ├── example-app/               ← `git clone`d, has its own .git/
│   ├── billing-api/
│   └── marketing-site/
│
├── projects/                      ← APEXSTACK DOCS PER PROJECT (committed)
│   ├── README.md
│   ├── ideas-backlog.md           ← shared ideas backlog
│   ├── example-app/
│   │   ├── README.md
│   │   ├── roadmap.md
│   │   ├── handover-assessment.md
│   │   ├── updates/
│   │   │   ├── weekly-2026-04-06.md
│   │   │   └── monthly-2026-03.md
│   │   └── notes/
│   ├── billing-api/
│   └── marketing-site/
│
└── docs/
    └── multi-project.md           ← this file
```

The split between `workspace/` and `projects/` is deliberate:

- **`workspace/<name>/`** is where you do code work. It's a real git clone of the project. Branches, PRs, and CI happen here. **Don't commit it to the ops repo** — it has its own remote.
- **`projects/<name>/`** is where ApexStack docs about the project live. It's part of the ops repo. Roadmaps, handover assessments, stakeholder updates all live here.

The test for "where does this doc go?" is **"would I want this to follow the code if the project was spun out tomorrow?"** If yes → put it in the project's own repo (i.e. inside `workspace/<name>/`). If no → put it in `projects/<name>/`.

---

## How skills behave in multi-project mode

Every skill that's portfolio-aware reads `apexstack.mode` first. If it's `multi-project`, the skill iterates the registry instead of acting on the current repo.

| Skill | Single-project behaviour | Multi-project behaviour |
|-------|--------------------------|-------------------------|
| `/projects` | Shows current repo as one row | Reads registry, shows N rows |
| `/status` | Git + PRs + issues for current repo | Same, per project, separated by headers |
| `/inbox` | PRs/issues/comments for current repo | Aggregated across all projects |
| `/tasks` | Actionable list for current repo | Aggregated, scored, and sorted across projects |
| `/idea` | Appends to `IDEAS.md` | Appends to `projects/ideas-backlog.md` |
| `/roadmap` | Reads `ROADMAP.md` | Reads `projects/<name>/roadmap.md`; asks which project if ambiguous |
| `/stakeholder-update` | One project's update | Portfolio rollup with a section per project |
| `/handover` | Writes to `projects/<name>/handover-assessment.md` (creates the folder) | Same, plus suggests adding the project to the registry |

Skills that aren't portfolio-aware (`/decide`, `/write-spec`, `/code-review`, `/security-review`, `/audit-deps`) work the same in both modes — they always operate on the current working directory.

---

## Migrating from single → multi

You don't have to migrate everything at once. The recommended order:

### Step 1 — Flip the mode

Edit `onboarding.yaml`:

```yaml
apexstack:
  mode: multi-project
```

Skills will start looking for `apexstack.projects.yaml`. If it doesn't exist yet, they'll print a clear error pointing you at the example file.

### Step 2 — Create the registry with one project

Start with **just one project** — the repo you're already in:

```yaml
version: 1
projects:
  - name: my-current-app
    repo: your-org/my-current-app
    workspace: .              # the current directory IS this project
    docs: projects/my-current-app
    status: active
```

This is the smallest viable multi-project setup: one project, one row.

### Step 3 — Move existing docs

Move your existing single-project docs into `projects/my-current-app/`:

```bash
mv ROADMAP.md projects/my-current-app/roadmap.md
mv IDEAS.md projects/ideas-backlog.md   # ideas become shared
```

(Keep the originals as redirect stubs if you want a transition period.)

### Step 4 — Add a second project

Once step 3 is working, add another project to the registry:

```yaml
- name: marketing-site
  repo: your-org/marketing-site
  docs: projects/marketing-site
  status: active
```

Run `/handover marketing-site` to generate the handover assessment and seed the README. Add `workspace/marketing-site/` if you want a local clone.

### Step 5 — Repeat

Add more projects as you bring them under management. There's no limit, but the registry gets unwieldy past ~15 projects — at that point consider splitting into multiple ops repos by domain.

---

## Going back: multi → single

You can revert at any time:

1. Set `apexstack.mode: single-project` in `onboarding.yaml`
2. Decide which project the ops repo "is" — usually the one whose docs were richest
3. Move that project's docs back to the root (`projects/<name>/roadmap.md` → `ROADMAP.md`)
4. Delete `apexstack.projects.yaml` (or keep it as a backup)
5. The other projects keep working independently — they just stop being aggregated

Nothing is destructive. The other projects' docs in `projects/` aren't deleted; they just stop being read by the portfolio skills.

---

## Trade-offs

### Pros of multi-project mode

- **One inbox**: `/inbox` shows everything waiting on you across the whole portfolio in 1 second
- **Portfolio visibility**: `/projects` is the dashboard a CTO actually uses
- **Cross-project docs have a home**: stakeholder updates, handover assessments, multi-quarter roadmaps belong somewhere durable
- **Consistent governance**: same rules, same hooks, same skills apply to every project — no drift
- **Onboarding new repos is a documented process**: `/handover` produces a real artefact

### Cons of multi-project mode

- **More moving parts**: a registry file, two directory conventions, mode-aware skills
- **Registry drift**: if a project changes name or moves repos, you have to update the registry by hand
- **Two layers of git**: the ops repo has its own git history, and each `workspace/<name>/` has its own — easy to confuse
- **Not magical**: there's no auto-discovery of repos in your GitHub org. You have to register each one explicitly. (This is on purpose — implicit discovery would be unsafe.)
- **Gitignore discipline required**: forgetting to gitignore `workspace/*/` will make your ops repo huge fast

### When the trade-off is worth it

Roughly: if you spend more than 10 hours/week coordinating across multiple repos, multi-project mode pays for itself. Below that, single-project mode is almost always better.

---

## FAQ

**Can I have two ops repos?** Yes. Some teams split by domain (e.g. one ops repo for product, one for platform). Each ops repo is independent.

**Can a project be in two registries?** Technically yes, but don't. It defeats the "single source of truth" benefit and creates conflicts in `projects/<name>/`. Pick one ops repo per project.

**Do I need to clone every project locally?** No. The `workspace` field is optional. Skills will use GitHub-only data and mark git fields as `(not cloned)` for projects without a local clone.

**Does `/decide` write AgDRs to the ops repo or the project repo?** The project repo. AgDRs are tied to commits, so they live with the code. `/decide` always writes to `{cwd}/docs/agdr/`, which means you need to `cd workspace/<name>/` first.

**Does the registry support globs?** No. It's an explicit list. If you want all repos in an org, use `gh repo list` to generate the file once and commit the result — but you should still curate it.

**Can I use this with Linear / Jira / etc.?** Yes. Set `ticket_prefix` per project in the registry. Skills that read tickets will use the right prefix per project.

---

## Related docs

- `apexstack.projects.yaml.example` — the registry schema
- `workspace/README.md` — the live working copies convention
- `projects/README.md` — the per-project docs convention
- `onboarding.yaml` — where you set the mode
- `.claude/skills/projects/SKILL.md` — the `/projects` skill spec
- `.claude/skills/inbox/SKILL.md` — the `/inbox` skill spec
- `.claude/skills/handover/SKILL.md` — the `/handover` skill spec
