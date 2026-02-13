# Agents

Claude Code agent definitions synced to downstream repos.

## Conventions

- One agent per `.md` file
- Filename becomes the agent name in downstream repos (e.g., `plan-reviewer.md`)
- Files are synced to `.claude/agents/` in downstream repos by default
- Keep agents focused on a single responsibility
- Use YAML frontmatter if metadata is needed

## Adding a New Agent

1. Create `agents/<agent-name>.md`
2. Update `sync-config/sync-config.yaml` if the agent should be excluded from specific profiles
3. Push to `main` — the sync workflow handles distribution
