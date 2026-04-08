# Software Development Lifecycle (SDLC)

How features move from idea to production.

---

## Overview

```
Planning --> Design --> Build --> Review --> QA --> Deploy --> Monitor
```

---

## Phase 1: Planning

### Entry Criteria
- Approved PRD from Product
- Design review complete (if UI involved)
- Priority assigned

### Activities

| Activity | Owner | Output |
|----------|-------|--------|
| Review PRD | Tech Lead | Clarified requirements |
| Technical spike (if needed) | Engineer | Proof of concept |
| Effort estimation | Tech Lead + Team | Time estimate |
| Sprint planning | Tech Lead | Tasks assigned |

### Exit Criteria
- Requirements understood
- Estimate provided to Product
- Tickets created and prioritized
- Work scheduled in sprint/cycle

---

## Phase 2: Technical Design

### Entry Criteria
- Feature in sprint
- Requirements clear

### Activities

| Activity | Owner | Output |
|----------|-------|--------|
| Write technical design | Tech Lead / Senior Engineer | Design document |
| Architecture review | Head of Engineering (if needed) | Approval |
| Break into tasks | Tech Lead | Task list with estimates |
| Identify risks | Tech Lead | Risk register |

### Exit Criteria
- Technical design approved
- Tasks created and assigned
- Risks documented

### When Architecture Review Required
- New service or bounded context
- New external integration
- New technology
- Major data model changes
- Performance-critical features

---

## Phase 3: Build

### Entry Criteria
- Technical design approved
- Tasks assigned
- Environment ready

### Pre-Build Gate (MANDATORY)

DO NOT START CODING until these exist in your ticket tracker:

| Requirement | How to Verify |
|-------------|---------------|
| Parent epic/feature ticket exists | Ticket with PRD link |
| User story tickets created | Sub-issues under parent |
| Each story has acceptance criteria | Checkboxes in description |
| Technical tasks broken down | Sub-issues or checklist |

### One Ticket at a Time (MANDATORY)

Work on ONE ticket at a time. Complete it fully before starting the next.

```
WRONG:
  Start #6 --> Start #7 --> Start #8 --> PR with all 3

RIGHT:
  Start #6 --> PR --> Review --> QA --> Done
  Start #7 --> PR --> Review --> QA --> Done
  Start #8 --> PR --> Review --> QA --> Done
```

### Development Flow

```
1. Create branch from main
   git checkout -b feature/TICKET-ID-description

2. Implement in small commits
   - Follow architecture principles
   - Follow coding conventions
   - Write tests as you go

3. Keep branch updated
   git rebase main regularly

4. Self-review before PR
   - Run lint/format
   - Run tests locally
   - Review own diff

5. Create PR with description
   - What: Summary of changes
   - Why: Link to ticket
   - How: Technical approach
   - Testing: How to verify
```

### Exit Criteria
- Code complete
- Tests written and passing
- PR created

---

## Phase 4: Code Review

### Entry Criteria
- PR submitted
- CI checks passing
- Self-review done

### Activities

| Activity | Owner | Output |
|----------|-------|--------|
| Code review | Tech Lead / Peer | Feedback |
| Address feedback | Engineer | Updated PR |
| Design review | Design (if UI) | Approval |
| Approve PR | Reviewer | Merge ready |

### Review Checklist
- [ ] Follows architecture principles
- [ ] Follows coding conventions
- [ ] Tests adequate and passing
- [ ] No security issues
- [ ] Performance acceptable
- [ ] Documentation updated

### Exit Criteria
- Code review approved
- Design review passed (if applicable)
- All CI checks green

---

## Phase 5: QA Verification (MANDATORY)

### Entry Criteria
- PR approved and merged
- Feature deployed to staging (or runnable locally)

### QA Gate

Tickets CANNOT move to Done without QA verification.

```
In Progress --> In Review --> QA --> Done
                               ^
                         MANDATORY STOP
                         QA must verify
```

### Activities

| Activity | Owner | Output |
|----------|-------|--------|
| Verify acceptance criteria | QA Engineer | Checklist complete |
| Test edge cases | QA Engineer | Bug reports (if any) |
| Regression check | QA Engineer | No regressions |
| Sign-off | QA Engineer | Approval to close |

### If QA Finds Issues
1. QA creates bug ticket linked to original
2. Original ticket stays in QA state
3. Engineer fixes bug in new PR
4. Re-run QA verification
5. Only move to Done when QA passes

---

## Phase 6: Deploy

### Entry Criteria
- Tests passed
- QA sign-off
- Security review (if required)

### Deployment Checklist
- [ ] Staging tested
- [ ] Feature flags configured (if applicable)
- [ ] Rollback plan ready
- [ ] Monitoring in place
- [ ] Team aware

### Exit Criteria
- Successfully deployed to production
- Smoke tests passing
- No errors in monitoring

---

## Phase 7: Monitor

### Entry Criteria
- Deployed to production

### Post-Launch
- Monitor for 24-48 hours
- Gradual rollout if feature-flagged
- Collect metrics for success criteria
- Address issues immediately

---

## Timelines

| Feature Size | Design | Build | Review & Test | Total |
|--------------|--------|-------|---------------|-------|
| Small (1-2 days) | 0.5 day | 1-2 days | 0.5 day | 2-3 days |
| Medium (3-5 days) | 1 day | 3-5 days | 1-2 days | 5-8 days |
| Large (1-2 weeks) | 2-3 days | 5-10 days | 2-3 days | 2-3 weeks |
| XL (2+ weeks) | 1 week | 2+ weeks | 1 week | 4+ weeks |

---

## Roles Summary

| Phase | Primary | Support |
|-------|---------|---------|
| Planning | Tech Lead | Product, Engineers |
| Design | Tech Lead | Head of Engineering |
| Build | Engineers | Tech Lead |
| Review | Tech Lead | Peers, Design |
| QA | QA Engineer | Engineers |
| Deploy | Platform/CI | Tech Lead |
| Monitor | SRE | Engineers |
