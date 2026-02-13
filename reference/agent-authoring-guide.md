# Agent Authoring Guide

Reference for writing Claude Code agent definition files in this hub.

---

## Overview

An **agent** is a single Markdown file that defines a specialized persona or workflow for Claude Code. Agents are simpler than skills — they're just `.md` files placed in the `agents/` directory.

When synced to downstream repos, agents land in `.claude/agents/` where Claude discovers and uses them.

---

## File Structure

```
agents/
├── README.md              # Hub-only index (not synced)
├── plan-reviewer.md       # One agent per file
├── terraform-expert.md
└── security-auditor.md
```

### Rules

| Rule | Details |
|------|---------|
| **One file per agent** | Each `.md` file defines exactly one agent |
| **Filename = agent name** | `terraform-expert.md` → agent named "terraform-expert" |
| **Kebab-case filenames** | `^[a-z][a-z0-9-]+\.md$` — lowercase, hyphens, ends in `.md` |
| **Non-empty** | File must have content (instructions for Claude) |
| **Single responsibility** | One agent = one specialized role or workflow |

---

## Optional YAML Frontmatter

Agent files can optionally include YAML frontmatter for metadata:

```markdown
---
name: "terraform-expert"
description: "Specialized in Terraform/OpenTofu IaC reviews and planning"
---

# Terraform Expert

You are a Terraform infrastructure specialist...
```

The frontmatter is optional — the filename alone is sufficient for discovery. Use frontmatter when you want to provide a richer description or additional metadata.

---

## Writing Effective Agents

### Structure

A typical agent file follows this pattern:

```markdown
# Agent Name

Brief description of what this agent does.

## Role

Define the agent's persona, expertise, and perspective.

## Instructions

Step-by-step guidance for how the agent should approach tasks.

## Constraints

Boundaries, limitations, or things the agent should avoid.
```

### Tips

- **Be specific** — "You are a Terraform module reviewer who checks for Azure Verified Module compliance" is better than "You help with Terraform"
- **Include examples** — show the agent what good output looks like
- **Define scope** — clarify what the agent should and shouldn't do
- **Reference tools** — tell the agent which tools to prefer (Read, Grep, Bash, etc.)

---

## Hub-Specific Conventions

### Naming
- Filename must match the agent's identity: `security-auditor.md` for a security review agent
- Avoid generic names: `helper.md`, `assistant.md`, `default.md`

### Sync Behavior
- All `.md` files in `agents/` are synced (except `README.md`, which is globally excluded)
- Excluded agents can be configured per-profile in `sync-config/sync-config.yaml`

### Validation
- Pre-commit hooks enforce: non-empty content, kebab-case filename
- Run `python3 hooks/validate_agents.py` locally to check before committing
