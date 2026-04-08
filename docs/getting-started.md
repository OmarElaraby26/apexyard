# Getting Started with ApexStack

This guide walks you through adopting ApexStack for your team.

---

## Prerequisites

- A GitHub repository for your project
- [Claude Code](https://claude.com/claude-code) installed
- Basic familiarity with Claude Code's CLAUDE.md system

---

## Step 1: Add ApexStack to Your Project

### Option A: Copy into your repo

```bash
# Clone ApexStack
git clone https://github.com/me2resh/apexstack.git /tmp/apexstack

# Copy into your project (as a hidden directory)
cp -r /tmp/apexstack your-project/.apexstack/

# Or copy into a visible directory
cp -r /tmp/apexstack your-project/apexstack/
```

### Option B: Git submodule

```bash
git submodule add https://github.com/me2resh/apexstack.git .apexstack
```

---

## Step 2: Configure for Your Team

Edit `onboarding.yaml` with your company details:

```yaml
company:
  name: "Acme Corp"
  mission: "Making widgets simple"

team:
  - name: "Alice"
    role: "tech-lead"
    department: "engineering"
  - name: "Bob"
    role: "backend-engineer"
    department: "engineering"
  - name: "Charlie"
    role: "product-manager"
    department: "product"

tech_stack:
  language: "TypeScript"
  framework: "Next.js"
  database: "PostgreSQL"
  hosting: "Vercel"
```

---

## Step 3: Connect to Claude Code

Add a reference to ApexStack in your project's `CLAUDE.md`:

```markdown
# My Project

## Development Stack
@.apexstack/CLAUDE.md

## Project-Specific Rules
[Your additional rules here]
```

This tells Claude Code to read the ApexStack configuration alongside your project rules.

---

## Step 4: Start Using It

### Ask Claude Code to act as a role

```
Review this PR as the QA Engineer
```

```
As the Security Auditor, check this code for vulnerabilities
```

### Use the workflow

```
I'm starting work on ticket #42. Walk me through the SDLC process.
```

### Generate documents from templates

```
Create a PRD for the user authentication feature
```

```
Write a technical design for the payment processing system
```

### Record decisions

```
I need to decide between PostgreSQL and DynamoDB for this service.
Create an AgDR.
```

---

## Customization

### Adding a Custom Role

Create a new file in `roles/your-department/your-role.md`:

```markdown
# Role: [Role Name]

## Identity
You are a [Role Name]. You [primary responsibility].

## Responsibilities
- [Responsibility 1]
- [Responsibility 2]

## Capabilities

### CAN Do
- [Capability 1]

### CANNOT Do
- [Limitation 1]

## Interfaces
| Direction | Role | Interaction |
|-----------|------|-------------|
| Reports to | [Role] | [How] |

## Escalate When
- [Condition 1]
```

### Modifying a Workflow

Edit files in `workflows/` to match your team's process. For example, if you don't have a separate QA phase, remove it from `workflows/sdlc.md`.

### Adding a Template

Drop new markdown templates in `templates/` and reference them in `CLAUDE.md`.

---

## What to Expect

After setup, Claude Code will:

1. **Understand your team structure** -- It knows who does what
2. **Follow your SDLC** -- It enforces workflow gates
3. **Use your standards** -- Code reviews follow the defined checklist
4. **Generate structured docs** -- PRDs, tech designs, ADRs from templates
5. **Track decisions** -- Agent Decision Records for technical choices

---

## Troubleshooting

### Claude Code doesn't seem to know about the stack

Make sure your `CLAUDE.md` references the stack:
```markdown
@.apexstack/CLAUDE.md
```

### Roles aren't being applied correctly

Check that the role file exists in the expected path under `roles/`.

### Workflows feel too heavy for my team

Customize! Edit `onboarding.yaml` to disable stages:
```yaml
workflows:
  require_prd: false
  require_technical_design: false
  require_qa_signoff: false
```

---

## Next Steps

- Browse the [roles](../roles/) to see all available role definitions
- Read the [workflows](../workflows/) to understand the development process
- Check the [templates](../templates/) for document formats
- Star the [GitHub repo](https://github.com/me2resh/apexstack) for updates
