# Skills

Claude Code skill definitions synced to downstream repos.

## Conventions

- Each skill is a directory containing at minimum a `SKILL.md` file
- Directory name becomes the skill name (e.g., `skills/terraform-plan/SKILL.md`)
- Skills are synced to `.claude/skills/` in downstream repos by default
- Include any supporting files the skill needs within its directory

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md`
2. Add any supporting files in the same directory
3. Update `sync-config/sync-config.yaml` if the skill should be excluded from specific profiles
4. Push to `main` — the sync workflow handles distribution
